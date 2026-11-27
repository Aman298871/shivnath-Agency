import React, { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react';
import { useAuth } from './AuthContext';
import apiClient, { API_BASE_URL } from '../api/client';

const RealTimeContext = createContext(null);

export const RealTimeProvider = ({ children }) => {
  const { token, isAuthenticated } = useAuth();
  const [syncStatus, setSyncStatus] = useState('offline'); // 'live' | 'connecting' | 'reconnecting' | 'offline'
  const [lastEvent, setLastEvent] = useState(null);
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);

  const listenersRef = useRef(new Map());
  const eventSourceRef = useRef(null);
  const reconnectTimeoutRef = useRef(null);
  const lastEventIdRef = useRef(localStorage.getItem('ww_last_event_id') || '');
  const retryCountRef = useRef(0);

  // Fetch persistent notifications on startup
  const fetchInitialNotifications = useCallback(async () => {
    if (!isAuthenticated) return;
    try {
      const res = await apiClient.get('/api/notifications/notifications/?limit=50');
      if (res.data?.success && Array.isArray(res.data?.notifications)) {
        const notifs = res.data.notifications.map((n) => ({
          id: n.id,
          type: n.notification_type || 'NOTIFICATION',
          title: n.title,
          message: n.message,
          timestamp: n.created_at,
          read: n.is_read,
          payload: { reference_id: n.reference_id },
        }));
        setNotifications(notifs);
        setUnreadCount(res.data.unread_count ?? notifs.filter((x) => !x.read).length);
      }
    } catch (err) {
      console.warn('Failed to load initial notifications:', err);
    }
  }, [isAuthenticated]);

  // Register listener for specific event types
  const subscribe = useCallback((eventType, callback) => {
    if (!listenersRef.current.has(eventType)) {
      listenersRef.current.set(eventType, new Set());
    }
    listenersRef.current.get(eventType).add(callback);

    return () => {
      if (listenersRef.current.has(eventType)) {
        listenersRef.current.get(eventType).delete(callback);
      }
    };
  }, []);

  const dispatchEvent = useCallback((event) => {
    setLastEvent(event);

    // Save Last-Event-ID for zero-loss recovery
    if (event.event_id) {
      lastEventIdRef.current = event.event_id;
      localStorage.setItem('ww_last_event_id', event.event_id);
    }

    // Add to notifications with deduplication
    const newNotif = {
      id: event.event_id || Date.now().toString(),
      type: event.type || event.event_type || 'EVENT',
      title: (event.type || event.event_type || 'System Notification').replace(/[._]/g, ' ').toUpperCase(),
      message: typeof event.payload === 'string' ? event.payload : (event.payload?.message || JSON.stringify(event.payload || {})),
      payload: event.payload || {},
      timestamp: event.timestamp || new Date().toISOString(),
      read: false,
    };

    setNotifications((prev) => {
      if (newNotif.id && prev.some((n) => n.id === newNotif.id)) {
        return prev;
      }
      return [newNotif, ...prev.slice(0, 49)];
    });
    setUnreadCount((prev) => prev + 1);

    // Notify registered listeners
    const evType = event.type || event.event_type;
    if (listenersRef.current.has(evType)) {
      listenersRef.current.get(evType).forEach((cb) => {
        try {
          cb(event);
        } catch (err) {
          console.error(`Error in event listener for ${evType}:`, err);
        }
      });
    }

    // Also notify wildcard '*' listeners
    if (listenersRef.current.has('*')) {
      listenersRef.current.get('*').forEach((cb) => {
        try {
          cb(event);
        } catch (err) {
          console.error('Error in wildcard event listener:', err);
        }
      });
    }
  }, []);

  const connectSSE = useCallback(async () => {
    if (!isAuthenticated || !token) {
      setSyncStatus('offline');
      return;
    }

    if (eventSourceRef.current) {
      eventSourceRef.current.close();
    }

    setSyncStatus('connecting');

    let ticket = null;
    try {
      const ticketRes = await apiClient.post('/api/events/ticket/', {});
      if (ticketRes.data?.success && ticketRes.data?.ticket) {
        ticket = ticketRes.data.ticket;
      }
    } catch (e) {
      // In case ticket exchange is unavailable, fallback gracefully
      console.warn('SSE ticket acquisition notice:', e);
    }

    const sseUrl = new URL(`${API_BASE_URL}/api/events/stream/`);
    if (ticket) {
      sseUrl.searchParams.set('ticket', ticket);
    } else {
      sseUrl.searchParams.set('token', token);
    }
    if (lastEventIdRef.current) {
      sseUrl.searchParams.set('last_event_id', lastEventIdRef.current);
    }

    try {
      const es = new EventSource(sseUrl.toString());
      eventSourceRef.current = es;

      es.onopen = () => {
        retryCountRef.current = 0;
        setSyncStatus('live');
      };

      // Listen for message events
      es.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          dispatchEvent(data);
        } catch {
          // Heartbeat comment or non-json message
        }
      };

      // Specific named event types
      const knownEvents = [
        'order.created',
        'order.updated',
        'payment.recorded',
        'payment.verified',
        'moq.updated',
        'delivery.origin_updated',
        'delivery.bands_updated',
        'employee.created',
        'employee.updated',
        'employee.disabled',
        'inventory.adjusted',
      ];

      knownEvents.forEach((type) => {
        es.addEventListener(type, (e) => {
          try {
            const data = JSON.parse(e.data);
            dispatchEvent(data);
          } catch (parseErr) {
            console.error(`Failed to parse SSE payload for ${type}:`, parseErr);
          }
        });
      });

      es.onerror = () => {
        es.close();
        retryCountRef.current += 1;

        // If the server doesn't support SSE or returns 404/502, don't get stuck in an aggressive reconnect loop
        if (retryCountRef.current > 3) {
          setSyncStatus('offline');
          // Slow down retry to every 60 seconds
          if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current);
          reconnectTimeoutRef.current = setTimeout(() => {
            if (isAuthenticated) {
              connectSSE();
            }
          }, 60000);
        } else {
          setSyncStatus('reconnecting');
          if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current);
          reconnectTimeoutRef.current = setTimeout(() => {
            if (isAuthenticated) {
              connectSSE();
            }
          }, 5000);
        }
      };
    } catch (err) {
      console.warn('Failed to initialize EventSource:', err);
      setSyncStatus('offline');
    }
  }, [isAuthenticated, token, dispatchEvent]);

  useEffect(() => {
    let pollInterval = null;
    if (isAuthenticated) {
      fetchInitialNotifications();
      connectSSE();
      // Fallback periodic poll every 30 seconds to guarantee fresh notifications even if SSE is offline
      pollInterval = setInterval(() => {
        fetchInitialNotifications();
      }, 30000);
    } else {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }
      setSyncStatus('offline');
    }

    return () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (pollInterval) {
        clearInterval(pollInterval);
      }
    };
  }, [isAuthenticated, connectSSE, fetchInitialNotifications]);

  const markAllAsRead = async () => {
    try {
      await apiClient.post('/api/notifications/notifications/', {});
    } catch (err) {
      console.warn('Failed to mark notifications read on server:', err);
    }
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    setUnreadCount(0);
  };

  const clearNotifications = () => {
    setNotifications([]);
    setUnreadCount(0);
  };

  return (
    <RealTimeContext.Provider
      value={{
        syncStatus,
        lastEvent,
        notifications,
        unreadCount,
        subscribe,
        markAllAsRead,
        clearNotifications,
        reconnect: connectSSE,
      }}
    >
      {children}
    </RealTimeContext.Provider>
  );
};

export const useRealTime = () => {
  const context = useContext(RealTimeContext);
  if (!context) {
    throw new Error('useRealTime must be used within a RealTimeProvider');
  }
  return context;
};
