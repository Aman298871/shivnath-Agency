import React, { useState, useEffect, useCallback } from 'react';
import { 
  Search, Filter, Eye, RefreshCw, CheckCircle2, Truck, AlertCircle, 
  XCircle, PauseCircle, PlayCircle, Factory, Calendar, DollarSign, 
  FileText, Clock, CreditCard, Bell, ChevronRight, X, Package 
} from 'lucide-react';
import StatusBadge from '../components/common/StatusBadge';
import Modal from '../components/common/Modal';
import apiClient, { API_BASE_URL } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { useRealTime } from '../context/RealTimeContext';

export default function Orders() {
  const { hasPermission } = useAuth();
  const { subscribe } = useRealTime();

  const [orders, setOrders] = useState([]);
  const [franchises, setFranchises] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [franchiseFilter, setFranchiseFilter] = useState('ALL');
  const [dateFilter, setDateFilter] = useState('ALL');

  // Real-time New Order Banner Notification
  const [newOrderBanner, setNewOrderBanner] = useState(null);

  // Selected Order for detail & status update
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [isUpdatingStatus, setIsUpdatingStatus] = useState(false);
  const [statusNote, setStatusNote] = useState('');
  const [actionError, setActionError] = useState('');
  const [actionSuccess, setActionSuccess] = useState('');

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

  // Dispatch & Delay Modal State
  const [isDelayModalOpen, setIsDelayModalOpen] = useState(false);
  const [expectedDispatchDate, setExpectedDispatchDate] = useState('');
  const [isDelayedFlag, setIsDelayedFlag] = useState(false);
  const [delayReasonText, setDelayReasonText] = useState('');
  const [revisedDeliveryDate, setRevisedDeliveryDate] = useState('');
  const [delayModalError, setDelayModalError] = useState('');

  // Payment Collection Modal State
  const [isPaymentModalOpen, setIsPaymentModalOpen] = useState(false);
  const [collectAmount, setCollectAmount] = useState('');
  const [collectMethod, setCollectMethod] = useState('CASH');
  const [collectRef, setCollectRef] = useState('');
  const [collectNotes, setCollectNotes] = useState('');
  const [paymentError, setPaymentError] = useState('');

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
      const ordList = res.data?.orders || res.data?.results || (Array.isArray(res.data) ? res.data : []);
      setOrders(ordList);
    } catch (err) {
      console.warn('Orders fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  }, [statusFilter, search]);

  const fetchFranchises = async () => {
    try {
      const res = await apiClient.get('/api/accounts/franchises/');
      const fList = res.data?.franchises || res.data?.results || (Array.isArray(res.data) ? res.data : []);
      setFranchises(fList);
    } catch (e) {
      console.warn('Franchises fetch error:', e);
    }
  };

  useEffect(() => {
    fetchOrders();
    fetchFranchises();

    // Auto-refresh when order events arrive over SSE
    const unsubCreated = subscribe('order.created', (data) => {
      fetchOrders();
      const payload = data?.payload || data;
      setNewOrderBanner({
        orderId: payload?.order_id || payload?.id || 'New',
        customerName: payload?.customer_name || 'Customer',
        amount: payload?.amount || payload?.grand_total || '',
      });
    });

    const unsubUpdated = subscribe('order.updated', () => fetchOrders());

    // 30-second fallback poll ensuring fresh orders even if SSE drops
    const pollInterval = setInterval(() => {
      fetchOrders();
    }, 30000);

    return () => {
      unsubCreated();
      unsubUpdated();
      clearInterval(pollInterval);
    };
  }, [fetchOrders, subscribe]);

  const handleUpdateStatus = async (newStatus, extraParams = {}) => {
    if (!selectedOrder) return;
    setActionError('');
    setActionSuccess('');
    setIsUpdatingStatus(true);

    try {
      const payload = {
        status: newStatus.toLowerCase(),
        notes: statusNote || `Status updated to ${newStatus} via Web Admin Portal`,
        ...extraParams,
      };

      const res = await apiClient.patch(`/api/orders/${selectedOrder.id}/status/`, payload);
      setActionSuccess(`Order status successfully updated to ${newStatus.toUpperCase()}`);
      
      // Update selected order view in-place if returned
      if (res.data?.order) {
        setSelectedOrder((prev) => ({ ...(prev || {}), ...res.data.order }));
      } else {
        setSelectedOrder((prev) => ({ ...(prev || {}), status: newStatus.toLowerCase(), ...extraParams }));
      }
      setStatusNote('');
      fetchOrders();
    } catch (err) {
      const msg = err.response?.data?.message || err.response?.data?.error || err.response?.data?.detail || err.message || 'Failed to update order status.';
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

  const handleSaveDelayAndSchedule = async (e) => {
    e.preventDefault();
    if (!selectedOrder) return;
    setDelayModalError('');

    if (isDelayedFlag && !delayReasonText.trim()) {
      setDelayModalError('Please provide an explanation for the delay.');
      return;
    }

    setIsUpdatingStatus(true);
    try {
      const payload = {
        status: selectedOrder.status || selectedOrder.order_status,
        expected_dispatch_date: expectedDispatchDate || null,
        is_delayed: isDelayedFlag,
        delay_reason: delayReasonText.trim(),
        revised_delivery_date: revisedDeliveryDate || null,
        notes: isDelayedFlag ? `Delay recorded: ${delayReasonText.trim()}` : 'Dispatch schedule updated',
      };

      const res = await apiClient.patch(`/api/orders/${selectedOrder.id}/status/`, payload);
      setIsDelayModalOpen(false);
      setSelectedOrder(res.data?.order || { ...selectedOrder, ...payload });
      fetchOrders();
    } catch (err) {
      const msg = err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to update schedule';
      setDelayModalError(msg);
    } finally {
      setIsUpdatingStatus(false);
    }
  };

  const handleCollectPayment = async (e) => {
    e.preventDefault();
    if (!selectedOrder || !collectAmount) return;
    setPaymentError('');
    setIsUpdatingStatus(true);

    try {
      await apiClient.post(`/api/billing/orders/${selectedOrder.id}/payments/`, {
        amount: parseFloat(collectAmount),
        payment_method: collectMethod,
        reference_number: collectRef.trim(),
        notes: collectNotes.trim() || 'Payment collected via Web Admin Portal',
      });

      setIsPaymentModalOpen(false);
      setCollectAmount('');
      setCollectRef('');
      setCollectNotes('');
      setSelectedOrder(null);
      fetchOrders();
    } catch (err) {
      const msg = err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to record payment.';
      setPaymentError(msg);
    } finally {
      setIsUpdatingStatus(false);
    }
  };

  const handleViewThermalReceipt = (orderId) => {
    const token = localStorage.getItem('ww_access_token');
    window.open(`${API_BASE_URL}/api/billing/orders/${orderId}/invoice/download/?token=${token}`, '_blank');
  };

  const filteredOrders = orders.filter((o) => {
    // 1. Text Search
    if (search) {
      const q = search.toLowerCase();
      const matchesSearch = 
        o.id?.toString().includes(q) ||
        o.order_code?.toLowerCase().includes(q) ||
        o.customer_name?.toLowerCase().includes(q) ||
        o.franchise_name?.toLowerCase().includes(q) ||
        o.phone?.includes(q);
      if (!matchesSearch) return false;
    }

    // 2. Franchise Filter
    if (franchiseFilter !== 'ALL') {
      const fId = o.serving_franchise_id || o.franchise || o.franchise_id;
      if (fId?.toString() !== franchiseFilter.toString()) return false;
    }

    // 3. Date Filter
    if (dateFilter !== 'ALL' && o.created_at) {
      const ordDate = new Date(o.created_at);
      const now = new Date();
      if (dateFilter === 'TODAY') {
        if (ordDate.toDateString() !== now.toDateString()) return false;
      } else if (dateFilter === 'WEEK') {
        const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        if (ordDate < weekAgo) return false;
      } else if (dateFilter === 'MONTH') {
        const monthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        if (ordDate < monthAgo) return false;
      }
    }

    return true;
  });

  return (
    <div className="space-y-6">
      {/* Real-time Order Arrival Banner */}
      {newOrderBanner && (
        <div className="flex items-center justify-between rounded-xl bg-gradient-to-r from-sky-600 to-indigo-600 px-4 py-3 text-white shadow-lg animate-fade-in">
          <div className="flex items-center space-x-3">
            <div className="rounded-lg bg-white/20 p-2">
              <Bell className="h-5 w-5 text-white animate-pulse" />
            </div>
            <div>
              <p className="font-bold text-sm">
                New Order #{newOrderBanner.orderId} Arrived!
              </p>
              <p className="text-xs text-sky-100">
                Customer: <span className="font-semibold text-white">{newOrderBanner.customerName}</span>
                {newOrderBanner.amount ? ` • ₹${newOrderBanner.amount}` : ''}
              </p>
            </div>
          </div>
          <div className="flex items-center space-x-2">
            <button
              onClick={() => {
                const found = orders.find((o) => o.id?.toString() === newOrderBanner.orderId?.toString());
                if (found) setSelectedOrder(found);
                setNewOrderBanner(null);
              }}
              className="inline-flex items-center space-x-1 rounded-lg bg-white px-3 py-1.5 text-xs font-bold text-sky-700 hover:bg-sky-50 shadow-sm"
            >
              <span>View Order</span>
              <ChevronRight className="h-4 w-4" />
            </button>
            <button
              onClick={() => setNewOrderBanner(null)}
              className="rounded-lg p-1 text-white/80 hover:bg-white/10"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        </div>
      )}

      {/* Page Title & Search Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Live Order Management</h1>
          <p className="text-sm text-slate-500">Monitor, dispatch, and manage live customer & franchise orders</p>
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
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
        {/* Search */}
        <div className="relative w-full">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by ID, Customer, Phone..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>

        {/* Status Filter */}
        <div className="flex items-center space-x-2">
          <Filter className="h-4 w-4 text-slate-400 shrink-0" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="w-full rounded-lg border border-slate-200 px-3 py-2 text-xs text-slate-700 focus:border-sky-500 focus:outline-none"
          >
            <option value="ALL">All Statuses</option>
            <option value="PENDING">Pending Approval</option>
            <option value="PLANT_APPROVAL">Plant Approval</option>
            <option value="CONFIRMED">Confirmed</option>
            <option value="PREPARING">Preparing</option>
            <option value="MANUFACTURING">Manufacturing Required</option>
            <option value="DISPATCH">Dispatched</option>
            <option value="DELIVERED">Delivered</option>
            <option value="ON_HOLD">On Hold</option>
            <option value="REJECTED">Rejected</option>
            <option value="CANCELLED">Cancelled</option>
          </select>
        </div>

        {/* Franchise Filter */}
        <div>
          <select
            value={franchiseFilter}
            onChange={(e) => setFranchiseFilter(e.target.value)}
            className="w-full rounded-lg border border-slate-200 px-3 py-2 text-xs text-slate-700 focus:border-sky-500 focus:outline-none"
          >
            <option value="ALL">All Fulfillment Points</option>
            <option value="0">Central Plant Only</option>
            {franchises.map((f) => (
              <option key={f.id} value={f.id}>
                {f.business_name || f.owner_name} ({f.city || 'Franchise'})
              </option>
            ))}
          </select>
        </div>

        {/* Date Filter */}
        <div>
          <select
            value={dateFilter}
            onChange={(e) => setDateFilter(e.target.value)}
            className="w-full rounded-lg border border-slate-200 px-3 py-2 text-xs text-slate-700 focus:border-sky-500 focus:outline-none"
          >
            <option value="ALL">All Dates</option>
            <option value="TODAY">Today</option>
            <option value="WEEK">Past 7 Days</option>
            <option value="MONTH">Past 30 Days</option>
          </select>
        </div>
      </div>

      {/* Orders Table */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Order Code</th>
                <th className="pb-3">Customer / Party</th>
                <th className="pb-3">Fulfillment</th>
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
                  <td colSpan="9" className="py-12 text-center text-slate-400">
                    No matching orders found.
                  </td>
                </tr>
              ) : (
                filteredOrders.map((ord) => {
                  const isDelayed = ord.is_delayed;
                  return (
                    <tr key={ord.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold text-sky-600">
                        {ord.order_code ? `#${ord.order_code}` : `#ORD-${ord.id}`}
                      </td>
                      <td className="py-3.5">
                        <p className="font-semibold text-slate-900">
                          {ord.customer_name || ord.franchise_name || 'Customer'}
                        </p>
                        <p className="text-[11px] text-slate-500">{ord.phone || ''}</p>
                      </td>
                      <td className="py-3.5 text-slate-600">
                        {(ord.order_source === 'DIRECT_COMPANY' || ord.order_source === 'WATER_WALLET' || ord.order_source === 'WATER_WALLET_REDEMPTION' || !ord.serving_franchise || (ord.franchise_name && ord.franchise_name.includes('Direct'))) ? (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[11px] bg-emerald-50 text-emerald-800 font-semibold border border-emerald-200 shadow-sm">
                            <span className="h-1.5 w-1.5 rounded-full bg-emerald-500"></span>
                            Central Plant (Direct)
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md text-[11px] bg-sky-50 text-sky-800 font-medium border border-sky-200">
                            <span className="h-1.5 w-1.5 rounded-full bg-sky-500"></span>
                            {ord.serving_franchise_name || ord.franchise_name || 'Franchise'}
                          </span>
                        )}
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
                        <div className="flex flex-col gap-1 items-start">
                          <StatusBadge status={ord.status || ord.order_status} type="order" />
                          {isDelayed && (
                            <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-bold bg-amber-100 text-amber-800">
                              DELAYED
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-3.5 text-slate-500">
                        {ord.created_at ? new Date(ord.created_at).toLocaleDateString() : 'Today'}
                      </td>
                      <td className="py-3.5 text-right">
                        <button
                          onClick={() => {
                            setSelectedOrder(ord);
                            setActionError('');
                            setActionSuccess('');
                          }}
                          className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2.5 py-1 text-xs font-semibold text-sky-600 hover:bg-sky-100 transition-colors"
                        >
                          <Eye className="h-3.5 w-3.5" />
                          <span>Manage</span>
                        </button>
                      </td>
                    </tr>
                  );
                })
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
          title={`Order #${selectedOrder.order_code || selectedOrder.id} — Management & Operations`}
          maxWidth="max-w-3xl"
        >
          <div className="space-y-5 text-xs max-h-[75vh] overflow-y-auto pr-1">
            {actionError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{actionError}</span>
              </div>
            )}

            {actionSuccess && (
              <div className="flex items-center space-x-2 rounded-lg bg-emerald-50 p-3 text-emerald-700 border border-emerald-200">
                <CheckCircle2 className="h-4 w-4 shrink-0" />
                <span>{actionSuccess}</span>
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
                  <p><span className="font-semibold text-amber-950">Category:</span> {selectedOrder.hold_reason_category || 'N/A'}</p>
                  <p className="mt-0.5"><span className="font-semibold text-amber-950">Detailed Reason:</span> {selectedOrder.hold_reason || 'No written explanation'}</p>
                  {selectedOrder.hold_at && (
                    <p className="text-amber-700 text-[11px] mt-1">Held on {new Date(selectedOrder.hold_at).toLocaleString()}</p>
                  )}
                </div>
              </div>
            )}

            {/* Special Status Banner: Delayed */}
            {selectedOrder.is_delayed && (
              <div className="rounded-xl border border-amber-300 bg-amber-50/90 p-4 space-y-1">
                <div className="flex items-center space-x-2 text-amber-900 font-bold text-sm">
                  <Clock className="h-4 w-4 text-amber-700" />
                  <span>Delivery Schedule Delayed</span>
                </div>
                <div className="text-amber-900 text-xs">
                  <p><span className="font-semibold text-amber-950">Delay Explanation:</span> {selectedOrder.delay_reason || 'Logistical or manufacturing delay'}</p>
                  {selectedOrder.revised_delivery_date && (
                    <p className="mt-0.5"><span className="font-semibold text-amber-950">Revised Delivery Date:</span> {selectedOrder.revised_delivery_date}</p>
                  )}
                  {selectedOrder.expected_dispatch_date && (
                    <p className="mt-0.5 text-amber-800"><span className="font-semibold">Expected Dispatch:</span> {selectedOrder.expected_dispatch_date}</p>
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
                  <p><span className="font-semibold text-rose-950">Category:</span> {selectedOrder.rejection_reason_category || 'N/A'}</p>
                  <p className="mt-0.5"><span className="font-semibold text-rose-950">Reason:</span> {selectedOrder.rejection_reason || 'No written explanation'}</p>
                  {selectedOrder.rejected_at && (
                    <p className="text-rose-700 text-[11px] mt-1">Rejected on {new Date(selectedOrder.rejected_at).toLocaleString()}</p>
                  )}
                </div>
              </div>
            )}

            {/* Needs Manufacturing Alert */}
            {selectedOrder.needs_manufacturing && selectedOrder.status !== 'rejected' && selectedOrder.status !== 'cancelled' && selectedOrder.status !== 'delivered' && (
              <div className="rounded-xl border border-indigo-200 bg-indigo-50/80 p-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div className="flex items-center space-x-2.5">
                  <Factory className="h-4 w-4 text-indigo-600 shrink-0" />
                  <div>
                    <p className="text-indigo-950 font-bold text-xs">Insufficient Finished Stock — Manufacturing Required</p>
                    <p className="text-indigo-700 text-[11px]">Initiate a production batch linked to this order to fulfill demand.</p>
                  </div>
                </div>
                <button
                  onClick={() => setIsManufactureModalOpen(true)}
                  className="inline-flex items-center space-x-1.5 rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-indigo-700 shadow-sm shrink-0 self-start sm:self-auto"
                >
                  <Factory className="h-3.5 w-3.5" />
                  <span>Initiate Manufacturing</span>
                </button>
              </div>
            )}

            {/* Customer & Delivery Details */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 rounded-xl bg-slate-50 p-4 border border-slate-100">
              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Customer / Party Details</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">
                  {selectedOrder.customer_name || selectedOrder.franchise_name || 'Customer'}
                </p>
                <p className="text-slate-600 mt-0.5 font-medium">{selectedOrder.phone || 'Phone not recorded'}</p>
                {selectedOrder.delivery_address && (
                  <p className="text-slate-600 mt-1 text-[11px] leading-relaxed">
                    <span className="font-semibold text-slate-800">Address:</span> {selectedOrder.delivery_address}
                  </p>
                )}
                {selectedOrder.delivery_charges && (
                  <p className="text-slate-500 mt-1 text-[10px]">
                    Delivery: ₹{selectedOrder.delivery_charges} {selectedOrder.delivery_distance_km ? `(${selectedOrder.delivery_distance_km} km)` : ''}
                  </p>
                )}
              </div>
              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Financials & Fulfillment</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">
                  ₹{parseFloat(selectedOrder.grand_total ?? selectedOrder.total_amount ?? selectedOrder.amount ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </p>
                <div className="mt-1 flex flex-wrap gap-1.5">
                  <StatusBadge status={selectedOrder.status || selectedOrder.order_status} type="order" />
                  <StatusBadge status={selectedOrder.payment_status || 'UNPAID'} type="payment" />
                  {selectedOrder.payment_mode && (
                    <span className="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold bg-slate-200 text-slate-800">
                      {selectedOrder.payment_mode}
                    </span>
                  )}
                </div>
                {selectedOrder.expected_dispatch_date && (
                  <p className="text-slate-600 mt-2 text-[11px]">
                    <span className="font-semibold text-slate-700">Expected Dispatch:</span> {selectedOrder.expected_dispatch_date}
                  </p>
                )}
                <div className="mt-2 text-[11px] space-y-0.5">
                  <p className="text-slate-600">
                    <span className="font-semibold text-slate-700">Fulfillment Route:</span>{' '}
                    {(selectedOrder.order_source === 'DIRECT_COMPANY' || selectedOrder.order_source === 'WATER_WALLET' || selectedOrder.order_source === 'WATER_WALLET_REDEMPTION' || !selectedOrder.serving_franchise || (typeof selectedOrder.franchise_name === 'string' && selectedOrder.franchise_name.includes('Direct'))) ? (
                      <span className="inline-flex items-center gap-1 font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">
                        <span className="h-1.5 w-1.5 rounded-full bg-emerald-500"></span>
                        Central Plant Direct Dispatch
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 font-medium text-sky-700 bg-sky-50 px-2 py-0.5 rounded border border-sky-200">
                        <span className="h-1.5 w-1.5 rounded-full bg-sky-500"></span>
                        {selectedOrder.serving_franchise_name || selectedOrder.franchise_name || 'Franchise Partner'}
                      </span>
                    )}
                  </p>
                  {selectedOrder.registered_franchise_name && (
                    <p className="text-slate-500 text-[10px]">
                      Customer Origin: {selectedOrder.registered_franchise_name}
                    </p>
                  )}
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
                      <th className="p-2.5">Item Description</th>
                      <th className="p-2.5 text-center">Qty</th>
                      <th className="p-2.5 text-right">Unit Price</th>
                      <th className="p-2.5 text-right">Subtotal</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {(!Array.isArray(selectedOrder.items) || selectedOrder.items.length === 0) ? (
                      <tr>
                        <td colSpan="4" className="p-4 text-center text-slate-400">
                          Total Order Package Amount: ₹{selectedOrder.grand_total ?? selectedOrder.total_amount ?? selectedOrder.amount ?? 0}
                        </td>
                      </tr>
                    ) : (
                      selectedOrder.items.map((it, idx) => (
                        <tr key={idx}>
                          <td className="p-2.5 font-medium text-slate-800">
                            {it?.product_name || `SKU #${it?.product_id || it?.product || 'Item'}`}
                          </td>
                          <td className="p-2.5 text-center font-bold text-slate-900">{it?.quantity ?? 1}</td>
                          <td className="p-2.5 text-right text-slate-600">₹{it?.unit_price ?? 0}</td>
                          <td className="p-2.5 text-right font-bold text-slate-900">
                            ₹{it?.total_price || ((it?.quantity ?? 1) * (it?.unit_price ?? 0))}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {/* Operational Action Buttons Bar */}
            <div className="border-t border-slate-100 pt-4 space-y-3">
              <h4 className="font-bold text-slate-800 uppercase tracking-wider text-[11px]">
                Order Operations & Lifecycle Actions
              </h4>
              {(() => {
                const cur = (selectedOrder.status || '').toLowerCase().trim();
                const isTerminal = ['delivered', 'cancelled', 'rejected'].includes(cur);
                return (
                  <div className="flex flex-wrap gap-2">
                    {/* 1. Order Placed -> Plant Approval */}
                    {cur === 'order_placement' && (
                      <button
                        disabled={isUpdatingStatus}
                        onClick={() => handleUpdateStatus('plant_approval')}
                        className="inline-flex items-center space-x-1.5 rounded-lg bg-indigo-50 px-3 py-2 text-xs font-semibold text-indigo-700 hover:bg-indigo-100 border border-indigo-200 disabled:opacity-50"
                      >
                        <CheckCircle2 className="h-4 w-4" />
                        <span>Confirm & Approve (Plant)</span>
                      </button>
                    )}

                    {/* 2. Plant Approved -> Bottling / Preparation */}
                    {cur === 'plant_approval' && (
                      <button
                        disabled={isUpdatingStatus}
                        onClick={() => handleUpdateStatus('preparing')}
                        className="inline-flex items-center space-x-1.5 rounded-lg bg-amber-50 px-3 py-2 text-xs font-semibold text-amber-700 hover:bg-amber-100 border border-amber-200 disabled:opacity-50"
                      >
                        <Package className="h-4 w-4" />
                        <span>Start Bottling / Preparing</span>
                      </button>
                    )}

                    {/* 3. Direct / Staged Dispatch */}
                    {['plant_approval', 'preparing', 'manufacturing', 'on_hold', 'invoice_generated'].includes(cur) && (
                      <button
                        disabled={isUpdatingStatus}
                        onClick={() => handleUpdateStatus('dispatch')}
                        className="inline-flex items-center space-x-1.5 rounded-lg bg-purple-50 px-3 py-2 text-xs font-semibold text-purple-700 hover:bg-purple-100 border border-purple-200 disabled:opacity-50"
                      >
                        <Truck className="h-4 w-4" />
                        <span>Mark Dispatched</span>
                      </button>
                    )}

                    {/* 4. Dispatched -> Delivered */}
                    {cur === 'dispatch' && (
                      <button
                        disabled={isUpdatingStatus}
                        onClick={() => handleUpdateStatus('delivered')}
                        className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-50 px-3 py-2 text-xs font-semibold text-emerald-700 hover:bg-emerald-100 border border-emerald-200 disabled:opacity-50"
                      >
                        <CheckCircle2 className="h-4 w-4" />
                        <span>Confirm Delivery</span>
                      </button>
                    )}

                    {/* 5. Resume from On Hold */}
                    {cur === 'on_hold' && (
                      <button
                        disabled={isUpdatingStatus}
                        onClick={() => handleUpdateStatus('plant_approval')}
                        className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-50 px-3 py-2 text-xs font-semibold text-emerald-700 hover:bg-emerald-100 border border-emerald-200 disabled:opacity-50"
                      >
                        <CheckCircle2 className="h-4 w-4" />
                        <span>Resume from Hold</span>
                      </button>
                    )}

                    {/* 6. Schedule Dispatch / Delay */}
                    {!isTerminal && (
                      <button
                        onClick={() => {
                          setExpectedDispatchDate(selectedOrder.expected_dispatch_date || '');
                          setIsDelayedFlag(selectedOrder.is_delayed || false);
                          setDelayReasonText(selectedOrder.delay_reason || '');
                          setRevisedDeliveryDate(selectedOrder.revised_delivery_date || '');
                          setDelayModalError('');
                          setIsDelayModalOpen(true);
                        }}
                        className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-50 px-3 py-2 text-xs font-semibold text-sky-700 hover:bg-sky-100 border border-sky-200"
                      >
                        <Calendar className="h-4 w-4" />
                        <span>Schedule Dispatch / Delay</span>
                      </button>
                    )}

                    {/* 7. Collect Payment */}
                    {(selectedOrder.payment_status || '').toUpperCase() !== 'PAID' && (
                      <button
                        onClick={() => {
                          setCollectAmount((selectedOrder.grand_total ?? selectedOrder.total_amount ?? selectedOrder.amount ?? 0).toString());
                          setPaymentError('');
                          setIsPaymentModalOpen(true);
                        }}
                        className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-600 px-3 py-2 text-xs font-semibold text-white hover:bg-emerald-700 shadow-sm"
                      >
                        <DollarSign className="h-4 w-4" />
                        <span>Collect Payment</span>
                      </button>
                    )}

                    {/* 8. View / Print Invoice */}
                    <button
                      onClick={() => handleViewThermalReceipt(selectedOrder.id)}
                      className="inline-flex items-center space-x-1.5 rounded-lg bg-slate-100 px-3 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-200 border border-slate-300"
                    >
                      <FileText className="h-4 w-4" />
                      <span>View / Print Invoice</span>
                    </button>

                    {/* 9. Put on Hold */}
                    {cur !== 'on_hold' && !isTerminal && (
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

                    {/* 10. Reject Order */}
                    {!isTerminal && (
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

                    {/* 11. Cancel Order */}
                    {!isTerminal && (
                      <button
                        disabled={isUpdatingStatus}
                        onClick={() => handleUpdateStatus('cancelled')}
                        className="inline-flex items-center space-x-1.5 rounded-lg bg-slate-100 px-3 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-200 border border-slate-300 disabled:opacity-50"
                      >
                        <XCircle className="h-4 w-4" />
                        <span>Cancel Order</span>
                      </button>
                    )}
                  </div>
                );
              })()}
            </div>
          </div>
        </Modal>
      )}

      {/* Put on Hold Modal with Mandatory Reason */}
      {isHoldModalOpen && selectedOrder && (
        <Modal
          isOpen={true}
          onClose={() => setIsHoldModalOpen(false)}
          title={`Put Order #${selectedOrder.order_code || selectedOrder.id} on Hold`}
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
          title={`Reject Order #${selectedOrder.order_code || selectedOrder.id}`}
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
                placeholder="Enter mandatory written justification for rejecting this order..."
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

      {/* Schedule Dispatch & Delay Settings Modal */}
      {isDelayModalOpen && selectedOrder && (
        <Modal
          isOpen={true}
          onClose={() => setIsDelayModalOpen(false)}
          title={`Dispatch & Delivery Scheduling — #${selectedOrder.order_code || selectedOrder.id}`}
          maxWidth="max-w-lg"
        >
          <form onSubmit={handleSaveDelayAndSchedule} className="space-y-4 text-xs">
            {delayModalError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{delayModalError}</span>
              </div>
            )}

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Expected Dispatch Date
              </label>
              <input
                type="date"
                value={expectedDispatchDate}
                onChange={(e) => setExpectedDispatchDate(e.target.value)}
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs font-medium text-slate-800 focus:outline-none focus:ring-2 focus:ring-sky-500"
              />
              <p className="text-[11px] text-slate-500 mt-1">Date when production will hand over items to delivery team.</p>
            </div>

            <div className="pt-2 border-t border-slate-100">
              <label className="flex items-center space-x-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={isDelayedFlag}
                  onChange={(e) => setIsDelayedFlag(e.target.checked)}
                  className="rounded text-amber-600 focus:ring-amber-500 h-4 w-4"
                />
                <span className="font-bold text-slate-800">Mark Order as Delayed</span>
              </label>
              <p className="text-[11px] text-slate-500 ml-6 mt-0.5">Alerts customer and franchise with delay explanation.</p>
            </div>

            {isDelayedFlag && (
              <div className="space-y-3 bg-amber-50 p-3.5 rounded-xl border border-amber-200">
                <div>
                  <label className="block text-amber-950 font-semibold mb-1">
                    Delay Explanation Reason <span className="text-rose-500">*</span>
                  </label>
                  <textarea
                    rows={2}
                    value={delayReasonText}
                    onChange={(e) => setDelayReasonText(e.target.value)}
                    placeholder="e.g. Bottling line maintenance, transit delay, high demand queue..."
                    className="w-full rounded-lg border border-amber-300 px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-amber-500 bg-white"
                  />
                </div>

                <div>
                  <label className="block text-amber-950 font-semibold mb-1">
                    Revised Expected Delivery Date
                  </label>
                  <input
                    type="date"
                    value={revisedDeliveryDate}
                    onChange={(e) => setRevisedDeliveryDate(e.target.value)}
                    className="w-full rounded-lg border border-amber-300 px-3 py-2 text-xs font-medium text-slate-800 focus:outline-none focus:ring-2 focus:ring-amber-500 bg-white"
                  />
                </div>
              </div>
            )}

            <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsDelayModalOpen(false)}
                className="rounded-lg border border-slate-300 px-3 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isUpdatingStatus}
                className="rounded-lg bg-sky-600 px-4 py-2 text-xs font-semibold text-white hover:bg-sky-700 disabled:opacity-50"
              >
                Save Schedule
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Collect Payment Modal */}
      {isPaymentModalOpen && selectedOrder && (
        <Modal
          isOpen={true}
          onClose={() => setIsPaymentModalOpen(false)}
          title={`Collect Payment for Order #${selectedOrder.order_code || selectedOrder.id}`}
          maxWidth="max-w-md"
        >
          <form onSubmit={handleCollectPayment} className="space-y-4 text-xs">
            {paymentError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{paymentError}</span>
              </div>
            )}

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Amount to Collect (₹) <span className="text-rose-500">*</span>
              </label>
              <input
                type="number"
                step="0.01"
                required
                value={collectAmount}
                onChange={(e) => setCollectAmount(e.target.value)}
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Payment Method <span className="text-rose-500">*</span>
              </label>
              <select
                value={collectMethod}
                onChange={(e) => setCollectMethod(e.target.value)}
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs font-semibold text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500 bg-white"
              >
                <option value="CASH">Cash Collection</option>
                <option value="UPI">UPI / QR Payment</option>
                <option value="BANK_TRANSFER">Direct Bank Transfer (NEFT/RTGS)</option>
                <option value="CHEQUE">Cheque</option>
              </select>
            </div>

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Reference / Transaction Number
              </label>
              <input
                type="text"
                value={collectRef}
                onChange={(e) => setCollectRef(e.target.value)}
                placeholder="e.g. UPI Ref, Cheque #, Bank UTR..."
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Collection Notes
              </label>
              <input
                type="text"
                value={collectNotes}
                onChange={(e) => setCollectNotes(e.target.value)}
                placeholder="e.g. Paid to driver on delivery, cashier receipt..."
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsPaymentModalOpen(false)}
                className="rounded-lg border border-slate-300 px-3 py-2 text-xs font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isUpdatingStatus}
                className="rounded-lg bg-emerald-600 px-4 py-2 text-xs font-semibold text-white hover:bg-emerald-700 disabled:opacity-50"
              >
                Record Payment
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Manufacturing Initiation Modal */}
      {isManufactureModalOpen && selectedOrder && (
        <Modal
          isOpen={true}
          onClose={() => setIsManufactureModalOpen(false)}
          title={`Initiate Production Batch — Order #${selectedOrder.order_code || selectedOrder.id}`}
          maxWidth="max-w-md"
        >
          <div className="space-y-4 text-xs">
            {manufactureError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{manufactureError}</span>
              </div>
            )}

            <div className="rounded-xl bg-indigo-50 p-3 border border-indigo-200 text-indigo-900">
              <p className="font-bold">Production Planning Integration</p>
              <p className="text-[11px] mt-0.5">
                Initiating production will flag this order in Central Bottling Plant queues and prompt raw material reservation.
              </p>
            </div>

            <div>
              <label className="block text-slate-700 font-semibold mb-1">
                Production Instructions / Notes
              </label>
              <textarea
                rows={3}
                value={manufactureNotes}
                onChange={(e) => setManufactureNotes(e.target.value)}
                placeholder="e.g. Priority bottling run for event delivery, batch packaging details..."
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
                Start Production
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
