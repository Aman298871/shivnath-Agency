import json
import time
from datetime import datetime
from django.views import View
from django.http import StreamingHttpResponse, JsonResponse
from django.utils import timezone
from django.core.paginator import Paginator
from django.db.models import Q
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken, AuthenticationFailed

from .models import SystemEvent, AdminAuditLog, UserProfile
from .permissions import IsAdminRole, HasGranularPermission, IsSuperAdminRole


def _authenticate_sse_request(request):
    """
    Authenticates an incoming SSE or polling request using Bearer header or query parameter 'token'.
    Returns (user, profile) or (None, None).
    """
    raw_token = None
    auth_header = request.META.get('HTTP_AUTHORIZATION', '')
    if auth_header.startswith('Bearer '):
        raw_token = auth_header.split('Bearer ')[1].strip()
    elif 'token' in request.GET:
        raw_token = request.GET.get('token', '').strip()

    if not raw_token:
        return None, None

    jwt_auth = JWTAuthentication()
    try:
        validated_token = jwt_auth.get_validated_token(raw_token)
        user = jwt_auth.get_user(validated_token)
        if not user or not user.is_active:
            return None, None
        profile = getattr(user, 'profile', None)
        if not profile or profile.status != 'active':
            return None, None
        return user, profile
    except (InvalidToken, AuthenticationFailed, Exception):
        return None, None


class RealTimeEventStreamView(View):
    """
    Server-Sent Events (SSE) streaming endpoint for live bi-directional synchronization.
    URL: /api/events/stream/
    - Authenticates via ?token=<jwt> or Authorization: Bearer <jwt>
    - Supports Last-Event-ID header/query param to replay missed events after disconnect
    - Emits events formatted as:
        id: <event_uuid>
        event: <event_type>
        data: {"event_id": "...", "type": "...", "payload": {...}, "timestamp": "..."}
    - Emits periodic heartbeat comments to keep HTTP proxies from terminating idle connections.
    """

    def get(self, request):
        user, profile = _authenticate_sse_request(request)
        if not user:
            return JsonResponse({'error': 'Unauthorized. Valid active JWT token required.'}, status=401)

        # Allow admin, super_admin, staff, stock_manager, sales_executive, franchise
        allowed_roles = ['admin', 'super_admin', 'staff', 'stock_manager', 'sales_executive', 'franchise']
        if profile.role not in allowed_roles:
            return JsonResponse({'error': 'Forbidden. Live sync is restricted to administrative and franchise operators.'}, status=403)

        last_event_id = request.META.get('HTTP_LAST_EVENT_ID') or request.GET.get('last_event_id')
        franchise_id = getattr(getattr(user, 'franchise_profile', None), 'id', None) if profile.role == 'franchise' else None

        def event_generator():
            yield "retry: 3000\n\n"
            yield f": connected to Water Wala real-time event bus as {user.username} [{profile.role}]\n\n"

            last_seen_created_at = timezone.now()

            # 1. Replay missed events if client reconnected with Last-Event-ID
            if last_event_id:
                try:
                    ref_event = SystemEvent.objects.filter(event_id=last_event_id).first()
                    if ref_event:
                        replays = SystemEvent.objects.filter(created_at__gt=ref_event.created_at).order_by('created_at')[:100]
                        for ev in replays:
                            if franchise_id and ev.target_scope == 'franchise' and ev.franchise_id != franchise_id:
                                continue
                            payload_data = json.dumps({
                                'event_id': str(ev.event_id),
                                'type': ev.event_type,
                                'payload': ev.payload,
                                'timestamp': ev.created_at.isoformat()
                            })
                            yield f"id: {ev.event_id}\nevent: {ev.event_type}\ndata: {payload_data}\n\n"
                            last_seen_created_at = max(last_seen_created_at, ev.created_at)
                except Exception:
                    pass

            # 2. Continuous event stream loop
            loops = 0
            max_loops = 120  # Keep connection open for up to ~120 seconds, client will auto-reconnect
            while loops < max_loops:
                loops += 1
                try:
                    new_events = SystemEvent.objects.filter(
                        created_at__gt=last_seen_created_at
                    ).order_by('created_at')[:20]

                    if new_events.exists():
                        for ev in new_events:
                            if franchise_id and ev.target_scope == 'franchise' and ev.franchise_id != franchise_id:
                                continue
                            payload_data = json.dumps({
                                'event_id': str(ev.event_id),
                                'type': ev.event_type,
                                'payload': ev.payload,
                                'timestamp': ev.created_at.isoformat()
                            })
                            yield f"id: {ev.event_id}\nevent: {ev.event_type}\ndata: {payload_data}\n\n"
                            last_seen_created_at = ev.created_at
                    else:
                        # Heartbeat every 3 iterations (~3 seconds)
                        if loops % 3 == 0:
                            yield f": heartbeat {timezone.now().isoformat()}\n\n"

                except Exception as stream_err:
                    yield f": error {str(stream_err)}\n\n"
                    break

                time.sleep(1)

        response = StreamingHttpResponse(event_generator(), content_type='text/event-stream')
        response['Cache-Control'] = 'no-cache, no-transform'
        response['X-Accel-Buffering'] = 'no'
        return response


class RealTimeEventLatestView(APIView):
    """
    REST polling fallback endpoint to fetch events since a specific event_id or timestamp.
    URL: /api/events/latest/
    Query params:
    - since_id: UUID of the last processed event
    - since_time: ISO timestamp
    - limit: maximum number of events (default: 50)
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        profile = getattr(user, 'profile', None)
        if not profile or profile.status != 'active':
            return Response({'error': 'Account is inactive.'}, status=status.HTTP_403_FORBIDDEN)

        since_id = request.GET.get('since_id') or request.GET.get('after_id')
        since_time = request.GET.get('since_time')
        limit = min(int(request.GET.get('limit', 50)), 100)

        qs = SystemEvent.objects.all().order_by('created_at')

        if since_id:
            ref_ev = SystemEvent.objects.filter(Q(event_id=since_id) | Q(id__str=since_id) if since_id.isdigit() else Q(event_id=since_id)).first()
            if ref_ev:
                qs = qs.filter(created_at__gt=ref_ev.created_at)
        elif since_time:
            try:
                parsed_time = datetime.fromisoformat(since_time)
                qs = qs.filter(created_at__gt=parsed_time)
            except Exception:
                pass

        if profile.role == 'franchise':
            franchise_id = getattr(getattr(user, 'franchise_profile', None), 'id', None)
            qs = qs.filter(Q(target_scope__in=['global', 'franchise']) & (Q(franchise_id=franchise_id) | Q(franchise_id__isnull=True)))

        events_list = list(qs[:limit])
        data = [
            {
                'event_id': str(ev.event_id),
                'type': ev.event_type,
                'event_type': ev.event_type,
                'payload': ev.payload,
                'target_scope': ev.target_scope,
                'timestamp': ev.created_at.isoformat()
            }
            for ev in events_list
        ]

        latest_id = str(events_list[-1].event_id) if events_list else since_id

        return Response({
            'success': True,
            'count': len(data),
            'latest_id': latest_id,
            'latest_event_id': latest_id,
            'events': data
        })


class AdminAuditLogListView(APIView):
    """
    Administrative Audit Trail Endpoint.
    URL: /api/accounts/audit-logs/
    - Only Super Admins or operational Admins with 'employees' / 'settings' permissions can view.
    - Supports search by actor name/email, action, resource_type, date range, and pagination.
    """
    permission_classes = [IsAuthenticated, HasGranularPermission(module='employees', action='view')]

    def get(self, request):
        search_query = request.GET.get('search', '').strip()
        action_filter = request.GET.get('action', '').strip()
        resource_type = request.GET.get('resource_type', '').strip()
        start_date = request.GET.get('start_date', '').strip()
        end_date = request.GET.get('end_date', '').strip()
        page_number = int(request.GET.get('page', 1))
        page_size = min(int(request.GET.get('page_size', 20)), 100)

        qs = AdminAuditLog.objects.select_related('actor').all()

        if search_query:
            qs = qs.filter(
                Q(actor__username__icontains=search_query) |
                Q(actor__email__icontains=search_query) |
                Q(actor__first_name__icontains=search_query) |
                Q(resource_id__icontains=search_query) |
                Q(action__icontains=search_query)
            )

        if action_filter:
            qs = qs.filter(action__icontains=action_filter)

        if resource_type:
            qs = qs.filter(resource_type__iexact=resource_type)

        if start_date:
            try:
                s_date = datetime.strptime(start_date, '%Y-%m-%d')
                qs = qs.filter(created_at__gte=s_date)
            except Exception:
                pass

        if end_date:
            try:
                e_date = datetime.strptime(end_date, '%Y-%m-%d')
                qs = qs.filter(created_at__lte=e_date.replace(hour=23, minute=59, second=59))
            except Exception:
                pass

        paginator = Paginator(qs, page_size)
        page_obj = paginator.get_page(page_number)

        logs_data = [
            {
                'id': log.id,
                'actor_id': log.actor_id,
                'actor_email': log.actor.email if log.actor else 'System',
                'actor_name': log.actor.get_full_name() or (log.actor.username if log.actor else 'System'),
                'action': log.action,
                'resource_type': log.resource_type,
                'resource_id': log.resource_id,
                'ip_address': log.ip_address,
                'changes': log.changes,
                'created_at': log.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            }
            for log in page_obj
        ]

        return Response({
            'success': True,
            'total_count': paginator.count,
            'total_pages': paginator.num_pages,
            'current_page': page_obj.number,
            'page_size': page_size,
            'has_next': page_obj.has_next(),
            'has_previous': page_obj.has_previous(),
            'results': logs_data,
            'logs': logs_data
        })
