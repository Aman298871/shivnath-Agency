import React, { useState, useEffect, useCallback } from 'react';
import { Search, Filter, Eye, RefreshCw, CheckCircle2, Truck, AlertCircle, XCircle } from 'lucide-react';
import StatusBadge from '../components/common/StatusBadge';
import Modal from '../components/common/Modal';
import apiClient from '../api/client';
import { useAuth } from '../context/AuthContext';
import { useRealTime } from '../context/RealTimeContext';

export default function Orders() {
  const { hasPermission } = useAuth();
  const { subscribe } = useRealTime();

  const [orders, setOrders] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Selected Order for detail & status update
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [isUpdatingStatus, setIsUpdatingStatus] = useState(false);
  const [statusNote, setStatusNote] = useState('');
  const [actionError, setActionError] = useState('');

  const fetchOrders = useCallback(async () => {
    try {
      setIsLoading(true);
      const params = new URLSearchParams();
      if (statusFilter !== 'ALL') {
        params.append('status', statusFilter.toLowerCase());
      }
      if (search) {
        params.append('search', search.trim());
      }
      const qs = params.toString();
      const url = qs ? `/api/orders/?${qs}` : '/api/orders/';
      const res = await apiClient.get(url);
      setOrders(res.data?.orders || res.data?.results || (Array.isArray(res.data) ? res.data : []));
    } catch (err) {
      console.warn('Orders fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  }, [statusFilter, search]);

  useEffect(() => {
    fetchOrders();

    // Auto-refresh when order events arrive over SSE
    const unsubCreated = subscribe('order.created', () => fetchOrders());
    const unsubUpdated = subscribe('order.updated', () => fetchOrders());

    return () => {
      unsubCreated();
      unsubUpdated();
    };
  }, [fetchOrders, subscribe]);

  const handleUpdateStatus = async (newStatus) => {
    if (!selectedOrder) return;
    setActionError('');
    setIsUpdatingStatus(true);

    try {
      await apiClient.patch(`/api/orders/${selectedOrder.id}/status/`, {
        status: newStatus.toLowerCase(),
        notes: statusNote || `Status updated to ${newStatus} via Web Admin Portal`,
      });
      setSelectedOrder(null);
      setStatusNote('');
      fetchOrders();
    } catch (err) {
      const msg = err.response?.data?.error || err.response?.data?.message || err.response?.data?.detail || err.message || 'Failed to update order status.';
      setActionError(msg);
    } finally {
      setIsUpdatingStatus(false);
    }
  };

  const filteredOrders = orders.filter((o) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      o.id?.toString().includes(q) ||
      o.customer_name?.toLowerCase().includes(q) ||
      o.franchise_name?.toLowerCase().includes(q) ||
      o.phone?.includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Page Title & Search Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Live Order Management</h1>
          <p className="text-sm text-slate-500">Monitor, dispatch, and manage live orders in real time</p>
        </div>

        <button
          onClick={fetchOrders}
          className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
        >
          <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Filters Toolbar */}
      <div className="flex flex-col sm:flex-row items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="relative flex-1 w-full">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by Order ID, customer, dealer..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>

        <div className="flex items-center space-x-2 w-full sm:w-auto">
          <Filter className="h-4 w-4 text-slate-400 shrink-0" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="w-full sm:w-44 rounded-lg border border-slate-200 px-3 py-2 text-xs text-slate-700 focus:border-sky-500 focus:outline-none"
          >
            <option value="ALL">All Statuses</option>
            <option value="PENDING">Pending</option>
            <option value="PROCESSING">Processing</option>
            <option value="CONFIRMED">Confirmed</option>
            <option value="DISPATCHED">Dispatched</option>
            <option value="OUT_FOR_DELIVERY">Out for Delivery</option>
            <option value="DELIVERED">Delivered</option>
            <option value="CANCELLED">Cancelled</option>
          </select>
        </div>
      </div>

      {/* Orders Table */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Order #</th>
                <th className="pb-3">Party Name</th>
                <th className="pb-3">Items / Qty</th>
                <th className="pb-3">Total Amount</th>
                <th className="pb-3">Payment</th>
                <th className="pb-3">Status</th>
                <th className="pb-3">Placed At</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredOrders.length === 0 ? (
                <tr>
                  <td colSpan="8" className="py-12 text-center text-slate-400">
                    No matching orders found.
                  </td>
                </tr>
              ) : (
                filteredOrders.map((ord) => (
                  <tr key={ord.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 font-bold text-sky-600">#{ord.id}</td>
                    <td className="py-3.5 font-medium text-slate-900">
                      {ord.customer_name || ord.franchise_name || 'Customer'}
                    </td>
                    <td className="py-3.5 text-slate-600">
                      {ord.items?.length || 1} SKU(s)
                    </td>
                    <td className="py-3.5 font-bold text-slate-900">
                      ₹{parseFloat(ord.total_amount || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-3.5">
                      <StatusBadge status={ord.payment_status || 'UNPAID'} type="payment" />
                    </td>
                    <td className="py-3.5">
                      <StatusBadge status={ord.order_status} type="order" />
                    </td>
                    <td className="py-3.5 text-slate-500">
                      {ord.created_at ? new Date(ord.created_at).toLocaleDateString() : 'Today'}
                    </td>
                    <td className="py-3.5 text-right">
                      <button
                        onClick={() => setSelectedOrder(ord)}
                        className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2.5 py-1 text-xs font-semibold text-sky-600 hover:bg-sky-100 transition-colors"
                      >
                        <Eye className="h-3.5 w-3.5" />
                        <span>Manage</span>
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Order Detail & Dispatch Management Modal */}
      {selectedOrder && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedOrder(null)}
          title={`Order #${selectedOrder.id} — Dispatch Control`}
          maxWidth="max-w-2xl"
        >
          <div className="space-y-5 text-xs">
            {actionError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{actionError}</span>
              </div>
            )}

            {/* Customer & Delivery Details */}
            <div className="grid grid-cols-2 gap-4 rounded-xl bg-slate-50 p-4 border border-slate-100">
              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Customer / Dealer</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">
                  {selectedOrder.customer_name || selectedOrder.franchise_name || 'Customer'}
                </p>
                <p className="text-slate-600 mt-0.5">{selectedOrder.phone || 'Phone not recorded'}</p>
              </div>
              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Order Value & Status</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">
                  ₹{parseFloat(selectedOrder.total_amount || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </p>
                <div className="mt-1 flex space-x-2">
                  <StatusBadge status={selectedOrder.order_status} />
                  <StatusBadge status={selectedOrder.payment_status || 'UNPAID'} type="payment" />
                </div>
              </div>
            </div>

            {/* Line Items List */}
            <div>
              <h4 className="font-bold text-slate-800 uppercase tracking-wider text-[11px] mb-2">Order Line Items</h4>
              <div className="rounded-xl border border-slate-200 overflow-hidden">
                <table className="w-full text-left">
                  <thead className="bg-slate-50 text-slate-500 font-semibold border-b border-slate-100">
                    <tr>
                      <th className="p-2.5">Item</th>
                      <th className="p-2.5 text-center">Qty</th>
                      <th className="p-2.5 text-right">Unit Price</th>
                      <th className="p-2.5 text-right">Subtotal</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {(selectedOrder.items || []).length === 0 ? (
                      <tr>
                        <td colSpan="4" className="p-4 text-center text-slate-400">
                          Total Order Package Amount: ₹{selectedOrder.total_amount}
                        </td>
                      </tr>
                    ) : (
                      selectedOrder.items.map((it, idx) => (
                        <tr key={idx}>
                          <td className="p-2.5 font-medium text-slate-800">{it.product_name || `SKU #${it.product_id}`}</td>
                          <td className="p-2.5 text-center font-bold text-slate-900">{it.quantity}</td>
                          <td className="p-2.5 text-right text-slate-600">₹{it.unit_price}</td>
                          <td className="p-2.5 text-right font-bold text-slate-900">₹{it.total_price || (it.quantity * it.unit_price)}</td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Status Transition Action Buttons */}
            {hasPermission('orders', 'edit') && (
              <div className="border-t border-slate-100 pt-4 space-y-3">
                <h4 className="font-bold text-slate-800 uppercase tracking-wider text-[11px]">Transition Order Lifecycle</h4>
                <div className="flex flex-wrap gap-2">
                  <button
                    disabled={isUpdatingStatus}
                    onClick={() => handleUpdateStatus('CONFIRMED')}
                    className="inline-flex items-center space-x-1.5 rounded-lg bg-indigo-50 px-3 py-2 text-xs font-semibold text-indigo-700 hover:bg-indigo-100 border border-indigo-200 disabled:opacity-50"
                  >
                    <CheckCircle2 className="h-4 w-4" />
                    <span>Confirm Order</span>
                  </button>

                  <button
                    disabled={isUpdatingStatus}
                    onClick={() => handleUpdateStatus('DISPATCHED')}
                    className="inline-flex items-center space-x-1.5 rounded-lg bg-purple-50 px-3 py-2 text-xs font-semibold text-purple-700 hover:bg-purple-100 border border-purple-200 disabled:opacity-50"
                  >
                    <Truck className="h-4 w-4" />
                    <span>Mark Dispatched</span>
                  </button>

                  <button
                    disabled={isUpdatingStatus}
                    onClick={() => handleUpdateStatus('DELIVERED')}
                    className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-50 px-3 py-2 text-xs font-semibold text-emerald-700 hover:bg-emerald-100 border border-emerald-200 disabled:opacity-50"
                  >
                    <CheckCircle2 className="h-4 w-4" />
                    <span>Mark Delivered</span>
                  </button>

                  <button
                    disabled={isUpdatingStatus}
                    onClick={() => handleUpdateStatus('CANCELLED')}
                    className="inline-flex items-center space-x-1.5 rounded-lg bg-rose-50 px-3 py-2 text-xs font-semibold text-rose-700 hover:bg-rose-100 border border-rose-200 disabled:opacity-50"
                  >
                    <XCircle className="h-4 w-4" />
                    <span>Cancel Order</span>
                  </button>
                </div>
              </div>
            )}
          </div>
        </Modal>
      )}
    </div>
  );
}
