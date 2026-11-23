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

    // Add to notifications
    const newNotif = {
      id: event.event_id || Date.now().toString(),
      type: event.type || event.event_type || 'EVENT',
      title: (event.type || event.event_type || 'System Notification').replace(/[._]/g, ' ').toUpperCase(),
      message: typeof event.payload === 'string' ? event.payload : (event.payload?.message || JSON.stringify(event.payload || {})),
      payload: event.payload || {},
      timestamp: event.timestamp || new Date().toISOString(),
      read: false,
    };

    setNotifications((prev) => [newNotif, ...prev.slice(0, 49)]);
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

  const connectSSE = useCallback(() => {
    if (!isAuthenticated || !token) {
      setSyncStatus('offline');
      return;
    }

    if (eventSourceRef.current) {
      eventSourceRef.current.close();
    }

    setSyncStatus('connecting');

    const sseUrl = new URL(`${API_BASE_URL}/api/events/stream/`);
    sseUrl.searchParams.set('token', token);
    if (lastEventIdRef.current) {
      sseUrl.searchParams.set('last_event_id', lastEventIdRef.current);
    }

    try {
      const es = new EventSource(sseUrl.toString());
      eventSourceRef.current = es;

      es.onopen = () => {
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
        setSyncStatus('reconnecting');
        es.close();

        // Auto-reconnect after 4 seconds
        if (reconnectTimeoutRef.current) clearTimeout(reconnectTimeoutRef.current);
        reconnectTimeoutRef.current = setTimeout(() => {
          if (isAuthenticated) {
            connectSSE();
          }
        }, 4000);
      };
    } catch (err) {
      console.warn('Failed to initialize EventSource:', err);
      setSyncStatus('offline');
    }
  }, [isAuthenticated, token, dispatchEvent]);

  useEffect(() => {
    if (isAuthenticated) {
      fetchInitialNotifications();
      connectSSE();
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
