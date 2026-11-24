import React, { useState, useEffect, useCallback } from 'react';
import { ShoppingCart, IndianRupee, Truck, AlertTriangle, Users, Building2, RefreshCw } from 'lucide-react';
import MetricCard from '../components/common/MetricCard';
import StatusBadge from '../components/common/StatusBadge';
import apiClient from '../api/client';
import { useRealTime } from '../context/RealTimeContext';

export default function Dashboard() {
  const [metrics, setMetrics] = useState({
    totalOrders: 0,
    totalRevenue: 0,
    pendingOrders: 0,
    deliveredOrders: 0,
    totalCustomers: 0,
    totalFranchises: 0,
    lowStockCount: 0,
  });
  const [recentOrders, setRecentOrders] = useState([]);
  const [lowStockProducts, setLowStockProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [fetchError, setFetchError] = useState('');
  const { subscribe } = useRealTime();

  const fetchDashboardData = useCallback(async () => {
    try {
      setIsLoading(true);
      setFetchError('');

      // 1. Authoritative Admin Dashboard Stats (Identical to Flutter Admin)
      let stats = {};
      try {
        const statsRes = await apiClient.get('/api/auth/admin/dashboard-stats/');
        stats = statsRes.data?.stats || statsRes.data || {};
      } catch (statsErr) {
        console.warn('Dashboard stats API error:', statsErr);
      }

      // 2. Fetch Real Orders from authoritative order endpoint
      let orders = [];
      try {
        const ordersRes = await apiClient.get('/api/orders/');
        orders = ordersRes.data?.orders || ordersRes.data?.results || (Array.isArray(ordersRes.data) ? ordersRes.data : []);
        setRecentOrders(orders.slice(0, 10));
      } catch (ordErr) {
        console.warn('Orders API error:', ordErr);
      }

      // 3. Fetch Real Inventory items for stock monitoring
      let alerts = [];
      try {
        const itemsRes = await apiClient.get('/api/inventory/items/');
        const items = itemsRes.data?.results || itemsRes.data?.items || (Array.isArray(itemsRes.data) ? itemsRes.data : []);
        alerts = items.filter((item) => (item.current_stock || item.quantity || 0) <= (item.threshold || item.minimum_stock_level || 20));
        setLowStockProducts(alerts.slice(0, 5));
      } catch (invErr) {
        console.warn('Inventory items API error:', invErr);
      }

      const ordStats = stats.orders || {};
      const custStats = stats.customers || {};
      const franStats = stats.franchises || {};

      setMetrics({
        totalOrders: ordStats.total || ordStats.total_orders || orders.length,
        totalRevenue: ordStats.total_value || ordStats.total_order_value || orders.reduce((sum, o) => sum + parseFloat(o.grand_total ?? o.total_amount ?? o.amount ?? 0), 0),
        pendingOrders: ordStats.pending || ordStats.pending_orders || orders.filter((o) => ['PENDING', 'PROCESSING', 'CONFIRMED'].includes((o.status || o.order_status || '').toUpperCase())).length,
        deliveredOrders: ordStats.delivered || ordStats.delivered_orders || orders.filter((o) => (o.status || o.order_status || '').toUpperCase() === 'DELIVERED').length,
        totalCustomers: custStats.total || custStats.total_customers || 0,
        totalFranchises: franStats.total || franStats.total_franchises || 0,
        lowStockCount: alerts.length,
      });
    } catch (err) {
      console.error('Dashboard fetch error:', err);
      setFetchError(err.message || 'Failed to load live dashboard metrics');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchDashboardData();

    // Subscribe to live SSE updates for automatic background re-fetch
    const unsubOrder = subscribe('order.created', () => fetchDashboardData());
    const unsubOrderUp = subscribe('order.updated', () => fetchDashboardData());
    const unsubPay = subscribe('payment.recorded', () => fetchDashboardData());
    const unsubInv = subscribe('inventory.adjusted', () => fetchDashboardData());

    return () => {
      unsubOrder();
      unsubOrderUp();
      unsubPay();
      unsubInv();
    };
  }, [fetchDashboardData, subscribe]);

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Executive Dashboard</h1>
          <p className="text-sm text-slate-500">Authoritative real-time multi-franchise operational snapshot</p>
        </div>
        <button
          onClick={fetchDashboardData}
          className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50 transition-colors cursor-pointer"
        >
          <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
          <span>Refresh Data</span>
        </button>
      </div>

      {fetchError && (
        <div className="rounded-xl border border-rose-200 bg-rose-50 p-4 text-xs text-rose-700">
          <strong>Sync Error:</strong> {fetchError}
        </div>
      )}

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <MetricCard
          title="Total Orders"
          value={metrics.totalOrders.toString()}
          subtitle={`${metrics.pendingOrders} pending • ${metrics.deliveredOrders} delivered`}
          icon={ShoppingCart}
          color="sky"
        />
        <MetricCard
          title="Total Order Value"
          value={`₹${parseFloat(metrics.totalRevenue || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}`}
          subtitle="All recorded transactions"
          icon={IndianRupee}
          color="emerald"
        />
        <MetricCard
          title="Active Customers"
          value={metrics.totalCustomers.toString()}
          subtitle="Registered customer profiles"
          icon={Users}
          color="indigo"
        />
        <MetricCard
          title="Authorized Franchises"
          value={metrics.totalFranchises.toString()}
          subtitle="Assigned distribution dealers"
          icon={Building2}
          color="amber"
        />
      </div>

      {/* Main Grid: Orders & Stock Alerts */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        {/* Recent Live Orders Table */}
        <div className="lg:col-span-2 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-base font-bold text-slate-900">Recent Live Orders</h2>
              <p className="text-xs text-slate-500">Real-time order intake across Customer & Franchise apps</p>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-3">Order ID</th>
                  <th className="pb-3">Customer / Dealer</th>
                  <th className="pb-3">Amount</th>
                  <th className="pb-3">Status</th>
                  <th className="pb-3">Date</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {recentOrders.length === 0 ? (
                  <tr>
                    <td colSpan="5" className="py-8 text-center text-slate-400">
                      No recent orders found.
                    </td>
                  </tr>
                ) : (
                  recentOrders.map((ord) => (
                    <tr key={ord.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3 font-semibold text-sky-600">
                        #{ord.id}
                      </td>
                      <td className="py-3 text-slate-800 font-medium">
                        {ord.customer_name || ord.franchise_name || 'Direct Customer'}
                      </td>
                      <td className="py-3 font-bold text-slate-900">
                        ₹{parseFloat(ord.grand_total ?? ord.total_amount ?? ord.amount ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                      </td>
                      <td className="py-3">
                        <StatusBadge status={ord.status || ord.order_status} />
                      </td>
                      <td className="py-3 text-slate-500">
                        {ord.created_at ? new Date(ord.created_at).toLocaleDateString() : 'Today'}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Low Stock Warning Sidebar */}
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-slate-900">Low Stock Warnings</h2>
            <span className="rounded-full bg-rose-50 px-2.5 py-0.5 text-xs font-semibold text-rose-700 border border-rose-200">
              {lowStockProducts.length} Alert{lowStockProducts.length !== 1 ? 's' : ''}
            </span>
          </div>

          <div className="space-y-3">
            {lowStockProducts.length === 0 ? (
              <div className="py-12 text-center text-xs text-slate-400">
                All inventory levels are above configured threshold levels.
              </div>
            ) : (
              lowStockProducts.map((alert, idx) => (
                <div key={idx} className="rounded-xl border border-amber-200 bg-amber-50/50 p-3.5 text-xs">
                  <div className="flex items-center justify-between font-semibold text-slate-800">
                    <span>{alert.product_name || `Product #${alert.product_id}`}</span>
                    <span className="text-rose-600 font-bold">{alert.current_stock || alert.quantity || 0} units left</span>
                  </div>
                  <p className="mt-1 text-[11px] text-slate-500">
                    Threshold: {alert.threshold || alert.minimum_stock_level || 10} units
                  </p>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
