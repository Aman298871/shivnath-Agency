import React, { useState, useEffect, useCallback } from 'react';
import { Search, Filter, Eye, RefreshCw, CheckCircle2, Truck, AlertCircle, XCircle, PauseCircle, PlayCircle, Factory } from 'lucide-react';
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

  // Hold Modal State
  const [isHoldModalOpen, setIsHoldModalOpen] = useState(false);
  const [holdCategory, setHoldCategory] = useState('INSUFFICIENT_STOCK');
  const [holdNotes, setHoldNotes] = useState('');
  const [holdError, setHoldError] = useState('');

  // Reject Modal State
  const [isRejectModalOpen, setIsRejectModalOpen] = useState(false);
  const [rejectCategory, setRejectCategory] = useState('PRODUCT_DISCONTINUED');
  const [rejectNotes, setRejectNotes] = useState('');
  const [rejectError, setRejectError] = useState('');

  // Manufacturing Modal State
  const [isManufactureModalOpen, setIsManufactureModalOpen] = useState(false);
  const [manufactureNotes, setManufactureNotes] = useState('');
  const [manufactureError, setManufactureError] = useState('');

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

  const handlePutOnHold = async () => {
    if (!selectedOrder) return;
    if (!holdNotes.trim()) {
      setHoldError('Please provide a mandatory written explanation for placing this order on hold.');
      return;
    }
    setHoldError('');
    setIsUpdatingStatus(true);

    try {
      await apiClient.post(`/api/orders/${selectedOrder.id}/hold/`, {
        reason_category: holdCategory,
        notes: holdNotes.trim(),
      });
      setIsHoldModalOpen(false);
      setHoldNotes('');
      setSelectedOrder(null);
      fetchOrders();
    } catch (err) {
      const msg = err.response?.data?.error || err.response?.data?.message || err.response?.data?.detail || err.message || 'Failed to put order on hold.';
      setHoldError(msg);
    } finally {
      setIsUpdatingStatus(false);
    }
  };

  const handleResumeOrder = async () => {
    if (!selectedOrder) return;
    setActionError('');
    setIsUpdatingStatus(true);

    try {
      await apiClient.post(`/api/orders/${selectedOrder.id}/resume/`, {
        target_status: 'plant_approval',
        notes: 'Order resumed from on hold via Web Admin Portal',
      });
      setSelectedOrder(null);
      fetchOrders();
    } catch (err) {
      const msg = err.response?.data?.error || err.response?.data?.message || err.response?.data?.detail || err.message || 'Failed to resume order.';
      setActionError(msg);
    } finally {
      setIsUpdatingStatus(false);
    }
  };

  const handleRejectOrder = async () => {
    if (!selectedOrder) return;
    if (!rejectNotes.trim()) {
      setRejectError('Please provide a mandatory written explanation for rejecting this order.');
      return;
    }
    setRejectError('');
    setIsUpdatingStatus(true);

    try {
      await apiClient.post(`/api/orders/${selectedOrder.id}/reject/`, {
        reason_category: rejectCategory,
        notes: rejectNotes.trim(),
      });
      setIsRejectModalOpen(false);
      setRejectNotes('');
      setSelectedOrder(null);
      fetchOrders();
    } catch (err) {
      const msg = err.response?.data?.error || err.response?.data?.message || err.response?.data?.detail || err.message || 'Failed to reject order.';
      setRejectError(msg);
    } finally {
      setIsUpdatingStatus(false);
    }
  };

  const handleInitiateManufacturing = async () => {
    if (!selectedOrder) return;
    setManufactureError('');
    setIsUpdatingStatus(true);

    try {
      await apiClient.post(`/api/orders/${selectedOrder.id}/manufacture/`, {
        notes: manufactureNotes.trim() || 'Initiated batch production from Web Admin Portal',
      });
      setIsManufactureModalOpen(false);
      setManufactureNotes('');
      setSelectedOrder(null);
      fetchOrders();
    } catch (err) {
      const msg = err.response?.data?.error || err.response?.data?.message || err.response?.data?.detail || err.message || 'Failed to initiate manufacturing.';
      setManufactureError(msg);
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
                      ₹{parseFloat(ord.grand_total ?? ord.total_amount ?? ord.amount ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="py-3.5">
                      <StatusBadge status={ord.payment_status || 'UNPAID'} type="payment" />
                    </td>
                    <td className="py-3.5">
                      <StatusBadge status={ord.status || ord.order_status} type="order" />
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

            {/* Special Status Banner: On Hold */}
            {selectedOrder.status === 'on_hold' && (
              <div className="rounded-xl border border-amber-300 bg-amber-50 p-4 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center space-x-2 text-amber-800 font-bold text-sm">
                    <PauseCircle className="h-4 w-4" />
                    <span>Order is Currently ON HOLD</span>
                  </div>
                  <button
                    disabled={isUpdatingStatus}
                    onClick={handleResumeOrder}
                    className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-700 shadow-sm transition-colors"
                  >
                    <PlayCircle className="h-3.5 w-3.5" />
                    <span>Resume Order</span>
                  </button>
                </div>
                <div className="text-amber-900 text-xs">
                  <p><span className="font-semibold text-amber-950">Reason Category:</span> {selectedOrder.hold_reason_category || 'N/A'}</p>
                  <p className="mt-0.5"><span className="font-semibold text-amber-950">Detailed Reason:</span> {selectedOrder.hold_reason || 'No written explanation'}</p>
                  {selectedOrder.hold_at && (
                    <p className="text-amber-700 text-[11px] mt-1">Held on {new Date(selectedOrder.hold_at).toLocaleString()}</p>
                  )}
                </div>
              </div>
            )}

            {/* Special Status Banner: Rejected */}
            {selectedOrder.status === 'rejected' && (
              <div className="rounded-xl border border-rose-300 bg-rose-50 p-4 space-y-1">
                <div className="flex items-center space-x-2 text-rose-800 font-bold text-sm">
                  <XCircle className="h-4 w-4" />
                  <span>Order has been REJECTED</span>
                </div>
                <div className="text-rose-900 text-xs">
                  <p><span className="font-semibold text-rose-950">Rejection Category:</span> {selectedOrder.rejection_reason_category || 'N/A'}</p>
                  <p className="mt-0.5"><span className="font-semibold text-rose-950">Detailed Reason:</span> {selectedOrder.rejection_reason || 'No written explanation'}</p>
                  {selectedOrder.rejected_at && (
                    <p className="text-rose-700 text-[11px] mt-1">Rejected on {new Date(selectedOrder.rejected_at).toLocaleString()}</p>
                  )}
                </div>
              </div>
            )}

            {/* Needs Manufacturing Alert */}
            {selectedOrder.needs_manufacturing && selectedOrder.status !== 'rejected' && selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'delivered' && (
              <div className="rounded-xl border border-indigo-200 bg-indigo-50/80 p-3.5 flex items-center justify-between">
                <div className="flex items-center space-x-2.5">
                  <Factory className="h-4 w-4 text-indigo-600 shrink-0" />
                  <div>
                    <p className="text-indigo-950 font-bold text-xs">Insufficient Finished Stock — Manufacturing Required</p>
                    <p className="text-indigo-700 text-[11px]">Initiate a production batch linked to this order to fulfil demand.</p>
                  </div>
                </div>
                <button
                  onClick={() => setIsManufactureModalOpen(true)}
                  className="inline-flex items-center space-x-1.5 rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700 shadow-sm shrink-0"
                >
                  <Factory className="h-3.5 w-3.5" />
                  <span>Initiate Manufacturing</span>
                </button>
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
                {selectedOrder.delivery_address && (
                  <p className="text-slate-500 mt-1 text-[11px] leading-relaxed"><span className="font-semibold text-slate-700">Address:</span> {selectedOrder.delivery_address}</p>
                )}
              </div>
              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Order Value & Status</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">
                  ₹{parseFloat(selectedOrder.grand_total ?? selectedOrder.total_amount ?? selectedOrder.amount ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </p>
                <div className="mt-1 flex flex-wrap gap-1.5">
                  <StatusBadge status={selectedOrder.status || selectedOrder.order_status} />
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
                          Total Order Package Amount: ₹{selectedOrder.grand_total ?? selectedOrder.total_amount ?? selectedOrder.amount ?? 0}
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
                  {selectedOrder.status !== 'on_hold' && selectedOrder.status !== 'delivered' && selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'rejected' && (
                    <button
                      disabled={isUpdatingStatus}
                      onClick={() => handleUpdateStatus('CONFIRMED')}
                      className="inline-flex items-center space-x-1.5 rounded-lg bg-indigo-50 px-3 py-2 text-xs font-semibold text-indigo-700 hover:bg-indigo-100 border border-indigo-200 disabled:opacity-50"
                    >
                      <CheckCircle2 className="h-4 w-4" />
                      <span>Confirm Order</span>
                    </button>
                  )}

                  {selectedOrder.status !== 'on_hold' && selectedOrder.status !== 'delivered' && selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'rejected' && (
                    <button
                      disabled={isUpdatingStatus}
                      onClick={() => handleUpdateStatus('DISPATCHED')}
                      className="inline-flex items-center space-x-1.5 rounded-lg bg-purple-50 px-3 py-2 text-xs font-semibold text-purple-700 hover:bg-purple-100 border border-purple-200 disabled:opacity-50"
                    >
                      <Truck className="h-4 w-4" />
                      <span>Mark Dispatched</span>
                    </button>
                  )}

                  {selectedOrder.status !== 'on_hold' && selectedOrder.status !== 'delivered' && selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'rejected' && (
                    <button
                      disabled={isUpdatingStatus}
                      onClick={() => handleUpdateStatus('DELIVERED')}
                      className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-50 px-3 py-2 text-xs font-semibold text-emerald-700 hover:bg-emerald-100 border border-emerald-200 disabled:opacity-50"
                    >
                      <CheckCircle2 className="h-4 w-4" />
                      <span>Mark Delivered</span>
                    </button>
                  )}

                  {/* Hold Action Button */}
                  {selectedOrder.status !== 'on_hold' && selectedOrder.status !== 'delivered' && selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'rejected' && (
                    <button
                      disabled={isUpdatingStatus}
                      onClick={() => {
                        setHoldCategory('INSUFFICIENT_STOCK');
                        setHoldNotes('');
                        setHoldError('');
                        setIsHoldModalOpen(true);
                      }}
                      className="inline-flex items-center space-x-1.5 rounded-lg bg-amber-50 px-3 py-2 text-xs font-semibold text-amber-700 hover:bg-amber-100 border border-amber-300 disabled:opacity-50"
                    >
                      <PauseCircle className="h-4 w-4" />
                      <span>Put on Hold</span>
                    </button>
                  )}

                  {/* Reject Action Button */}
                  {selectedOrder.status !== 'delivered' && selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'rejected' && (
                    <button
                      disabled={isUpdatingStatus}
                      onClick={() => {
                        setRejectCategory('PRODUCT_DISCONTINUED');
                        setRejectNotes('');
                        setRejectError('');
                        setIsRejectModalOpen(true);
                      }}
                      className="inline-flex items-center space-x-1.5 rounded-lg bg-rose-50 px-3 py-2 text-xs font-semibold text-rose-700 hover:bg-rose-100 border border-rose-300 disabled:opacity-50"
                    >
                      <XCircle className="h-4 w-4" />
                      <span>Reject Order</span>
                    </button>
                  )}

                  {/* Standard Cancel Button */}
                  {selectedOrder.status !== 'delivered' && selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'rejected' && (
                    <button
                      disabled={isUpdatingStatus}
                      onClick={() => handleUpdateStatus('CANCELLED')}
                      className="inline-flex items-center space-x-1.5 rounded-lg bg-slate-100 px-3 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-200 border border-slate-300 disabled:opacity-50"
                    >
                      <XCircle className="h-4 w-4" />
                      <span>Cancel Order</span>
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>
        </Modal>
      )}

      {/* Put on Hold Modal with Mandatory Reason */}
      {isHoldModalOpen && selectedOrder && (
        <Modal
          isOpen={true}
          onClose={() => setIsHoldModalOpen(false)}
          title={`Put Order #${selectedOrder.id} on Hold`}
          maxWidth="max-w-lg"
        >
          <div className="space-y-4 text-xs">
            {holdError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{holdError}</span>
              </div>
            )}
            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Reason Category <span className="text-rose-500">*</span>
              </label>
              <select
                value={holdCategory}
                onChange={(e) => setHoldCategory(e.target.value)}
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs font-medium text-slate-800 focus:outline-none focus:ring-2 focus:ring-amber-500 bg-white"
              >
                <option value="INSUFFICIENT_STOCK">Insufficient finished stock</option>
                <option value="MANUFACTURING_REQUIRED">Manufacturing required</option>
                <option value="RAW_MATERIAL_UNAVAILABLE">Raw material unavailable</option>
                <option value="PRODUCTION_DELAY">Production delay</option>
                <option value="QUALITY_INSPECTION">Quality inspection pending</option>
                <option value="LOGISTICS_ISSUE">Delivery / logistics issue</option>
                <option value="OTHER">Other</option>
              </select>
            </div>

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Detailed Explanation <span className="text-rose-500">*</span>
              </label>
              <textarea
                rows={3}
                value={holdNotes}
                onChange={(e) => setHoldNotes(e.target.value)}
                placeholder="Enter mandatory written justification for placing order on hold..."
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-amber-500"
              />
            </div>

            <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsHoldModalOpen(false)}
                className="rounded-lg border border-slate-300 px-3 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isUpdatingStatus}
                onClick={handlePutOnHold}
                className="rounded-lg bg-amber-600 px-4 py-2 text-xs font-semibold text-white hover:bg-amber-700 disabled:opacity-50"
              >
                Confirm Put on Hold
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Reject Order Modal with Mandatory Reason */}
      {isRejectModalOpen && selectedOrder && (
        <Modal
          isOpen={true}
          onClose={() => setIsRejectModalOpen(false)}
          title={`Reject Order #${selectedOrder.id}`}
          maxWidth="max-w-lg"
        >
          <div className="space-y-4 text-xs">
            {rejectError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{rejectError}</span>
              </div>
            )}

            <div className="rounded-lg bg-amber-50 p-3 border border-amber-200 text-amber-800">
              <p className="font-semibold">Payment Safety Notice</p>
              <p className="text-[11px] mt-0.5">Rejecting this order does NOT automatically issue unauthorized refunds. Any refunds must be audited and processed through authorized accounting workflows.</p>
            </div>

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Rejection Category <span className="text-rose-500">*</span>
              </label>
              <select
                value={rejectCategory}
                onChange={(e) => setRejectCategory(e.target.value)}
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs font-medium text-slate-800 focus:outline-none focus:ring-2 focus:ring-rose-500 bg-white"
              >
                <option value="PRODUCT_DISCONTINUED">Product discontinued / not available</option>
                <option value="MANUFACTURING_NOT_POSSIBLE">Manufacturing not possible</option>
                <option value="OUT_OF_SERVICE_AREA">Out of service area</option>
                <option value="INVALID_ORDER_DETAILS">Invalid order details</option>
                <option value="OTHER">Other</option>
              </select>
            </div>

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Detailed Explanation <span className="text-rose-500">*</span>
              </label>
              <textarea
                rows={3}
                value={rejectNotes}
                onChange={(e) => setRejectNotes(e.target.value)}
                placeholder="Enter mandatory written justification for rejecting order..."
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-rose-500"
              />
            </div>

            <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsRejectModalOpen(false)}
                className="rounded-lg border border-slate-300 px-3 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isUpdatingStatus}
                onClick={handleRejectOrder}
                className="rounded-lg bg-rose-600 px-4 py-2 text-xs font-semibold text-white hover:bg-rose-700 disabled:opacity-50"
              >
                Confirm Rejection
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Initiate Manufacturing Modal */}
      {isManufactureModalOpen && selectedOrder && (
        <Modal
          isOpen={true}
          onClose={() => setIsManufactureModalOpen(false)}
          title={`Initiate Manufacturing for Order #${selectedOrder.id}`}
          maxWidth="max-w-lg"
        >
          <div className="space-y-4 text-xs">
            {manufactureError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{manufactureError}</span>
              </div>
            )}

            <div className="rounded-lg bg-indigo-50 p-3 border border-indigo-200 text-indigo-900">
              <p className="font-semibold text-sm">Production Batch Linking</p>
              <p className="text-[11px] mt-1 text-indigo-700">
                This will create a plant production batch linked directly to Order #{selectedOrder.id}.
                When production completes, the generated stock will be reserved for this customer order without altering the Order ID.
              </p>
            </div>

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Batch Production Notes / Instructions
              </label>
              <textarea
                rows={3}
                value={manufactureNotes}
                onChange={(e) => setManufactureNotes(e.target.value)}
                placeholder="Optional batch production remarks..."
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </div>

            <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsManufactureModalOpen(false)}
                className="rounded-lg border border-slate-300 px-3 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isUpdatingStatus}
                onClick={handleInitiateManufacturing}
                className="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-semibold text-white hover:bg-indigo-700 disabled:opacity-50"
              >
                Create Linked Batch & Start
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
