import React, { useState, useEffect, useRef } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';
import { useRealTime } from '../../context/RealTimeContext';
import { NewOrderAlertModal, NewStockRequestAlertModal } from '../common/OperationalAlertModals';
import apiClient from '../../api/client';

export default function AdminLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const { subscribe } = useRealTime();
  const navigate = useNavigate();

  // Alert modal states
  const [activeNewOrder, setActiveNewOrder] = useState(null);
  const [activeStockRequest, setActiveStockRequest] = useState(null);

  // Polling baseline & deduplication tracking
  const lastKnownOrderIdRef = useRef(0);
  const lastKnownStockReqIdRef = useRef(0);
  const isBaselineLoadedRef = useRef(false);

  // 1. Subscribe to Real-Time SSE Events
  useEffect(() => {
    const unsubOrder = subscribe('order.created', (event) => {
      if (event?.payload) {
        setActiveNewOrder(event.payload);
      }
    });

    const unsubStock = subscribe('stock.requested', (event) => {
      if (event?.payload) {
        setActiveStockRequest(event.payload);
      }
    });

    return () => {
      unsubOrder();
      unsubStock();
    };
  }, [subscribe]);

  // 2. Fallback Active Operational Poller (matches Flutter Admin's 60s background monitor)
  useEffect(() => {
    let isCancelled = false;

    const pollOperationalEvents = async () => {
      try {
        // Poll orders
        const ordersRes = await apiClient.get('/api/orders/?limit=10');
        const orders = ordersRes.data?.results || ordersRes.data?.orders || ordersRes.data?.data || (Array.isArray(ordersRes.data) ? ordersRes.data : []);

        if (Array.isArray(orders) && orders.length > 0) {
          const maxId = Math.max(...orders.map((o) => Number(o.id) || 0));

          if (!isBaselineLoadedRef.current) {
            lastKnownOrderIdRef.current = maxId;
          } else if (maxId > lastKnownOrderIdRef.current) {
            lastKnownOrderIdRef.current = maxId;
            const newest = orders.find((o) => Number(o.id) === maxId);
            if (newest && !isCancelled) {
              setActiveNewOrder(newest);
            }
          }
        }

        // Poll franchise stock requests
        const stockRes = await apiClient.get('/api/inventory/dealer-requests/?limit=10');
        const requests = stockRes.data?.results || stockRes.data?.requests || stockRes.data?.data || (Array.isArray(stockRes.data) ? stockRes.data : []);

        if (Array.isArray(requests) && requests.length > 0) {
          const maxReqId = Math.max(...requests.map((r) => Number(r.id) || 0));

          if (!isBaselineLoadedRef.current) {
            lastKnownStockReqIdRef.current = maxReqId;
          } else if (maxReqId > lastKnownStockReqIdRef.current) {
            lastKnownStockReqIdRef.current = maxReqId;
            const newestReq = requests.find((r) => Number(r.id) === maxReqId);
            if (newestReq && !isCancelled) {
              setActiveStockRequest(newestReq);
            }
          }
        }

        isBaselineLoadedRef.current = true;
      } catch (err) {
        // Gracefully ignore background network polling jitter
      }
    };

    pollOperationalEvents();
    const interval = setInterval(pollOperationalEvents, 45000);

    return () => {
      isCancelled = true;
      clearInterval(interval);
    };
  }, []);

  return (
    <div className="flex h-screen bg-slate-100 overflow-hidden">
      {/* Mobile sidebar overlay */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-40 bg-slate-900/50 backdrop-blur-sm lg:hidden transition-opacity"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      {/* Main Sidebar */}
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Content wrapper */}
      <div className="flex flex-1 flex-col overflow-hidden">
        <Header onMenuToggle={() => setSidebarOpen((prev) => !prev)} />

        <main className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8">
          <Outlet />
        </main>
      </div>

      {/* Real-Time Actionable Operational Popups (matches Flutter Admin UX) */}
      <NewOrderAlertModal
        order={activeNewOrder}
        isOpen={Boolean(activeNewOrder)}
        onClose={() => setActiveNewOrder(null)}
        onOpenOrder={(order) => {
          setActiveNewOrder(null);
          navigate('/orders', { state: { targetOrderId: order.id } });
        }}
      />

      <NewStockRequestAlertModal
        request={activeStockRequest}
        isOpen={Boolean(activeStockRequest)}
        onClose={() => setActiveStockRequest(null)}
        onOpenRequest={(req) => {
          setActiveStockRequest(null);
          navigate('/plant-stock', { state: { targetRequestId: req.id } });
        }}
      />
    </div>
  );
}
