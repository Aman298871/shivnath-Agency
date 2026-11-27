import React, { useState, useEffect } from 'react';
import {
  Receipt,
  Search,
  CheckCircle,
  Download,
  CreditCard,
  RefreshCw,
  AlertCircle,
  FileText,
  Clock,
  XCircle,
  Truck,
  Users,
  ChevronRight,
  Printer
} from 'lucide-react';
import StatusBadge from '../components/common/StatusBadge';
import Modal from '../components/common/Modal';
import apiClient, { API_BASE_URL } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { useRealTime } from '../context/RealTimeContext';

export default function Billing() {
  const { hasPermission } = useAuth();
  const { subscribe } = useRealTime();

  const [activeTab, setActiveTab] = useState('invoices'); // invoices | pending | outstanding | delivery
  const [invoices, setInvoices] = useState([]);
  const [pendingPayments, setPendingPayments] = useState([]);
  const [outstandingData, setOutstandingData] = useState([]);
  const [deliveryBands, setDeliveryBands] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Record payment modal
  const [recordModalOpen, setRecordModalOpen] = useState(false);
  const [selectedInvoice, setSelectedInvoice] = useState(null);
  const [payAmount, setPayAmount] = useState('');
  const [payMethod, setPayMethod] = useState('CASH');
  const [payRef, setPayRef] = useState('');
  const [payNotes, setPayNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Verify / Reject Payment Transaction modal
  const [txnActionModalOpen, setTxnActionModalOpen] = useState(false);
  const [selectedTxn, setSelectedTxn] = useState(null);
  const [txnActionType, setTxnActionType] = useState('verify'); // verify | reject
  const [rejectionReason, setRejectionReason] = useState('');

  const fetchInvoices = async () => {
    try {
      setIsLoading(true);
      const res = await apiClient.get('/api/billing/invoices/?page_size=100');
      const data = res.data?.results || res.data?.invoices || res.data || [];
      setInvoices(Array.isArray(data) ? data : []);
    } catch (err) {
      console.warn('Invoices fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchPendingPayments = async () => {
    try {
      const res = await apiClient.get('/api/billing/pending-payments/');
      const data = res.data?.results || res.data?.pending_payments || res.data || [];
      setPendingPayments(Array.isArray(data) ? data : []);
    } catch (err) {
      console.warn('Pending payments fetch error:', err);
    }
  };

  const fetchOutstanding = async () => {
    try {
      const res = await apiClient.get('/api/billing/customer-outstanding/');
      const data = res.data?.results || res.data?.customers || res.data || [];
      setOutstandingData(Array.isArray(data) ? data : []);
    } catch (err) {
      console.warn('Customer outstanding fetch error:', err);
    }
  };

  const fetchDeliveryBands = async () => {
    try {
      const res = await apiClient.get('/api/billing/delivery/bands/');
      const data = res.data?.results || res.data || [];
      setDeliveryBands(Array.isArray(data) ? data : []);
    } catch (err) {
      console.warn('Delivery bands fetch error:', err);
    }
  };

  const loadCurrentTabData = () => {
    if (activeTab === 'invoices') fetchInvoices();
    else if (activeTab === 'pending') fetchPendingPayments();
    else if (activeTab === 'outstanding') fetchOutstanding();
    else if (activeTab === 'delivery') fetchDeliveryBands();
  };

  useEffect(() => {
    loadCurrentTabData();

    const unsubPay = subscribe('payment.recorded', () => {
      fetchInvoices();
      fetchPendingPayments();
    });
    const unsubVer = subscribe('payment.verified', () => {
      fetchInvoices();
      fetchPendingPayments();
    });

    return () => {
      unsubPay();
      unsubVer();
    };
  }, [activeTab, subscribe]);

  const handleRecordPayment = async (e) => {
    e.preventDefault();
    if (!selectedInvoice || !payAmount) return;
    setIsSubmitting(true);

    try {
      await apiClient.post(`/api/billing/invoices/${selectedInvoice.id}/payments/`, {
        amount: parseFloat(payAmount),
        payment_method: payMethod,
        reference_number: payRef,
        notes: payNotes,
      });
      setRecordModalOpen(false);
      setSelectedInvoice(null);
      setPayAmount('');
      setPayRef('');
      setPayNotes('');
      fetchInvoices();
    } catch (err) {
      alert(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to record payment');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleTxnActionSubmit = async (e) => {
    e.preventDefault();
    if (!selectedTxn) return;
    setIsSubmitting(true);

    try {
      if (txnActionType === 'verify') {
        await apiClient.post(`/api/billing/payments/${selectedTxn.id}/verify/`, {
          remarks: 'Approved by Admin via Web Console',
        });
      } else {
        await apiClient.post(`/api/billing/payments/${selectedTxn.id}/reject/`, {
          reason: rejectionReason || 'Payment rejected due to invalid reference',
        });
      }
      setTxnActionModalOpen(false);
      setSelectedTxn(null);
      setRejectionReason('');
      fetchPendingPayments();
      fetchInvoices();
    } catch (err) {
      alert(err.response?.data?.message || err.response?.data?.error || err.message || 'Payment approval action failed');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDownloadReceipt = (invoiceId) => {
    const token = localStorage.getItem('ww_access_token');
    window.open(`${API_BASE_URL}/api/billing/invoices/${invoiceId}/thermal/?token=${token}`, '_blank');
  };

  const handleDownloadPdf = (invoiceId) => {
    const token = localStorage.getItem('ww_access_token');
    window.open(`${API_BASE_URL}/api/billing/invoices/${invoiceId}/download/?token=${token}`, '_blank');
  };

  // Summaries
  const totalBilled = invoices.reduce((sum, inv) => sum + parseFloat(inv.grand_total ?? inv.total_amount ?? 0), 0);
  const totalCollected = invoices.reduce((sum, inv) => sum + parseFloat(inv.amount_paid ?? inv.paid ?? 0), 0);
  const totalBalance = Math.max(0, totalBilled - totalCollected);

  const filteredInvoices = invoices.filter((inv) => {
    const matchesSearch =
      !search ||
      inv.id?.toString().includes(search.toLowerCase()) ||
      inv.invoice_number?.toLowerCase().includes(search.toLowerCase()) ||
      inv.customer_name?.toLowerCase().includes(search.toLowerCase()) ||
      inv.franchise_name?.toLowerCase().includes(search.toLowerCase());

    const total = parseFloat(inv.grand_total ?? inv.total_amount ?? 0);
    const paid = parseFloat(inv.amount_paid ?? inv.paid ?? 0);
    const balance = Math.max(0, total - paid);

    let status = 'UNPAID';
    if (paid >= total && total > 0) status = 'PAID';
    else if (paid > 0) status = 'PARTIAL';

    const matchesStatus =
      statusFilter === 'ALL' ||
      statusFilter === status ||
      inv.status?.toUpperCase() === statusFilter;

    return matchesSearch && matchesStatus;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Billing, Invoices & Financial Operations</h1>
          <p className="text-sm text-slate-500">
            GST compliant invoices, pending bank/UPI verifications, customer outstanding ledger, and delivery pricing
          </p>
        </div>

        <button
          onClick={loadCurrentTabData}
          className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
        >
          <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Metrics Row */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
          <div className="text-xs font-medium text-slate-500 uppercase tracking-wider">Total Billed</div>
          <div className="mt-1 text-2xl font-bold text-slate-900">₹{totalBilled.toLocaleString('en-IN', { maximumFractionDigits: 2 })}</div>
          <div className="mt-1 text-xs text-slate-400">{invoices.length} invoices generated</div>
        </div>
        <div className="rounded-xl border border-emerald-100 bg-emerald-50/50 p-4 shadow-sm">
          <div className="text-xs font-medium text-emerald-700 uppercase tracking-wider">Total Collections</div>
          <div className="mt-1 text-2xl font-bold text-emerald-800">₹{totalCollected.toLocaleString('en-IN', { maximumFractionDigits: 2 })}</div>
          <div className="mt-1 text-xs text-emerald-600">Verified cash, UPI & NEFT receipts</div>
        </div>
        <div className="rounded-xl border border-rose-100 bg-rose-50/50 p-4 shadow-sm">
          <div className="text-xs font-medium text-rose-700 uppercase tracking-wider">Outstanding Balance</div>
          <div className="mt-1 text-2xl font-bold text-rose-800">₹{totalBalance.toLocaleString('en-IN', { maximumFractionDigits: 2 })}</div>
          <div className="mt-1 text-xs text-rose-600">Pending customer & franchise settlements</div>
        </div>
      </div>

      {/* Navigation Tabs */}
      <div className="flex border-b border-slate-200 bg-white px-4 rounded-xl shadow-sm">
        <button
          onClick={() => setActiveTab('invoices')}
          className={`flex items-center space-x-2 border-b-2 py-3 px-4 text-xs font-semibold transition-colors ${
            activeTab === 'invoices' ? 'border-sky-600 text-sky-600' : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Receipt className="h-4 w-4" />
          <span>Tax Invoices ({invoices.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('pending')}
          className={`flex items-center space-x-2 border-b-2 py-3 px-4 text-xs font-semibold transition-colors ${
            activeTab === 'pending' ? 'border-sky-600 text-sky-600' : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Clock className="h-4 w-4" />
          <span>Pending Approvals ({pendingPayments.length})</span>
          {pendingPayments.length > 0 && (
            <span className="ml-1 rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-bold text-amber-800">
              {pendingPayments.length}
            </span>
          )}
        </button>

        <button
          onClick={() => setActiveTab('outstanding')}
          className={`flex items-center space-x-2 border-b-2 py-3 px-4 text-xs font-semibold transition-colors ${
            activeTab === 'outstanding' ? 'border-sky-600 text-sky-600' : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Users className="h-4 w-4" />
          <span>Customer Ledger</span>
        </button>

        <button
          onClick={() => setActiveTab('delivery')}
          className={`flex items-center space-x-2 border-b-2 py-3 px-4 text-xs font-semibold transition-colors ${
            activeTab === 'delivery' ? 'border-sky-600 text-sky-600' : 'border-transparent text-slate-500 hover:text-slate-700'
          }`}
        >
          <Truck className="h-4 w-4" />
          <span>Delivery Bands</span>
        </button>
      </div>

      {/* TAB 1: INVOICES */}
      {activeTab === 'invoices' && (
        <div className="space-y-4">
          {/* Search & Filter Toolbar */}
          <div className="flex flex-col sm:flex-row gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
            <div className="relative flex-1">
              <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search by invoice #, customer name, phone, or dealer..."
                className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
              />
            </div>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="rounded-lg border border-slate-200 px-3 py-2 text-xs font-medium text-slate-700 focus:border-sky-500 focus:outline-none"
            >
              <option value="ALL">All Payment Statuses</option>
              <option value="PAID">Paid</option>
              <option value="PARTIAL">Partially Paid</option>
              <option value="UNPAID">Unpaid</option>
            </select>
          </div>

          {/* Invoices Table */}
          <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                  <tr>
                    <th className="pb-3">Invoice #</th>
                    <th className="pb-3">Recipient Party</th>
                    <th className="pb-3">Total Amount</th>
                    <th className="pb-3">Paid Amount</th>
                    <th className="pb-3">Balance</th>
                    <th className="pb-3">Status</th>
                    <th className="pb-3">Issued Date</th>
                    <th className="pb-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredInvoices.length === 0 ? (
                    <tr>
                      <td colSpan="8" className="py-12 text-center text-slate-400">
                        No billing records matching your query.
                      </td>
                    </tr>
                  ) : (
                    filteredInvoices.map((inv) => {
                      const total = parseFloat(inv.grand_total ?? inv.total_amount ?? inv.total ?? 0);
                      const paid = parseFloat(inv.amount_paid ?? inv.paid ?? inv.paid_amount ?? 0);
                      const balance = Math.max(0, total - paid);
                      return (
                        <tr key={inv.id} className="hover:bg-slate-50/80 transition-colors">
                          <td className="py-3.5 font-bold font-mono text-sky-600">
                            {inv.invoice_number || `INV-${inv.id}`}
                          </td>
                          <td className="py-3.5 font-medium text-slate-900">
                            <div>{inv.customer_name || inv.franchise_name || inv.billed_to_name || 'Retail Party'}</div>
                            {inv.customer_phone && <div className="text-[10px] text-slate-400">{inv.customer_phone}</div>}
                          </td>
                          <td className="py-3.5 font-bold text-slate-900">₹{total.toFixed(2)}</td>
                          <td className="py-3.5 font-semibold text-emerald-600">₹{paid.toFixed(2)}</td>
                          <td className="py-3.5 font-bold text-rose-600">₹{balance.toFixed(2)}</td>
                          <td className="py-3.5">
                            <StatusBadge status={inv.status || (balance === 0 && total > 0 ? 'PAID' : paid > 0 ? 'PARTIAL' : 'UNPAID')} type="payment" />
                          </td>
                          <td className="py-3.5 text-slate-500">
                            {inv.issued_at || inv.created_at || inv.invoice_date ? new Date(inv.issued_at || inv.created_at || inv.invoice_date).toLocaleDateString() : 'Today'}
                          </td>
                          <td className="py-3.5 text-right space-x-1 whitespace-nowrap">
                            {hasPermission('billing', 'edit') && balance > 0 && (
                              <button
                                onClick={() => {
                                  setSelectedInvoice(inv);
                                  setPayAmount(balance.toString());
                                  setRecordModalOpen(true);
                                }}
                                className="inline-flex items-center space-x-1 rounded-md bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-100"
                              >
                                <CreditCard className="h-3 w-3" />
                                <span>Collect</span>
                              </button>
                            )}
                            <button
                              onClick={() => handleDownloadReceipt(inv.id)}
                              title="Print thermal receipt"
                              className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                            >
                              <Printer className="h-3 w-3" />
                              <span>Thermal</span>
                            </button>
                            <button
                              onClick={() => handleDownloadPdf(inv.id)}
                              title="Download GST invoice PDF"
                              className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2 py-1 text-xs font-semibold text-sky-700 hover:bg-sky-100"
                            >
                              <Download className="h-3 w-3" />
                              <span>PDF</span>
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
        </div>
      )}

      {/* TAB 2: PENDING APPROVALS */}
      {activeTab === 'pending' && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
          <div className="flex items-center justify-between pb-4 border-b border-slate-100">
            <div>
              <h2 className="text-sm font-bold text-slate-900">Payment Transactions Awaiting Verification</h2>
              <p className="text-xs text-slate-500">Customer and franchise offline payments, UPI UTR numbers, and bank transfers</p>
            </div>
            <button
              onClick={fetchPendingPayments}
              className="inline-flex items-center space-x-1 text-xs font-semibold text-sky-600 hover:text-sky-700"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              <span>Refresh Queue</span>
            </button>
          </div>

          <div className="overflow-x-auto mt-4">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-3">Txn ID / Ref</th>
                  <th className="pb-3">Party Name</th>
                  <th className="pb-3">Order / Invoice</th>
                  <th className="pb-3">Amount</th>
                  <th className="pb-3">Method</th>
                  <th className="pb-3">Submitted At</th>
                  <th className="pb-3 text-right">Decision</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {pendingPayments.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="py-12 text-center text-slate-400">
                      No pending payment verification requests in the queue.
                    </td>
                  </tr>
                ) : (
                  pendingPayments.map((txn) => (
                    <tr key={txn.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold font-mono text-slate-900">
                        <div>TXN-{txn.id}</div>
                        <div className="text-[10px] text-slate-400 font-normal">Ref: {txn.reference_number || txn.transaction_id || 'N/A'}</div>
                      </td>
                      <td className="py-3.5 font-medium text-slate-900">
                        {txn.user_name || txn.customer_name || txn.franchise_name || 'Customer'}
                      </td>
                      <td className="py-3.5 text-slate-600">
                        {txn.order_code ? `Order: ${txn.order_code}` : txn.invoice_number ? `Inv: ${txn.invoice_number}` : 'General Settlement'}
                      </td>
                      <td className="py-3.5 font-bold text-emerald-600">
                        ₹{parseFloat(txn.amount || 0).toFixed(2)}
                      </td>
                      <td className="py-3.5 font-semibold text-slate-700">
                        {txn.payment_method || 'UPI'}
                      </td>
                      <td className="py-3.5 text-slate-500">
                        {txn.created_at ? new Date(txn.created_at).toLocaleString() : 'Recent'}
                      </td>
                      <td className="py-3.5 text-right space-x-2 whitespace-nowrap">
                        <button
                          onClick={() => {
                            setSelectedTxn(txn);
                            setTxnActionType('verify');
                            setTxnActionModalOpen(true);
                          }}
                          className="inline-flex items-center space-x-1 rounded-md bg-emerald-600 px-2.5 py-1 text-xs font-semibold text-white hover:bg-emerald-500"
                        >
                          <CheckCircle className="h-3 w-3" />
                          <span>Approve</span>
                        </button>
                        <button
                          onClick={() => {
                            setSelectedTxn(txn);
                            setTxnActionType('reject');
                            setTxnActionModalOpen(true);
                          }}
                          className="inline-flex items-center space-x-1 rounded-md bg-rose-50 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-100"
                        >
                          <XCircle className="h-3 w-3" />
                          <span>Reject</span>
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 3: CUSTOMER OUTSTANDING LEDGER */}
      {activeTab === 'outstanding' && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
          <div className="flex items-center justify-between pb-4 border-b border-slate-100">
            <div>
              <h2 className="text-sm font-bold text-slate-900">Customer Outstanding Balance Ledger</h2>
              <p className="text-xs text-slate-500">Authoritative balance breakdown reconciling delivered unpaid orders and invoices</p>
            </div>
            <button
              onClick={fetchOutstanding}
              className="inline-flex items-center space-x-1 text-xs font-semibold text-sky-600 hover:text-sky-700"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              <span>Refresh Ledger</span>
            </button>
          </div>

          <div className="overflow-x-auto mt-4">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-3">Customer Name</th>
                  <th className="pb-3">Phone</th>
                  <th className="pb-3">Assigned Franchise</th>
                  <th className="pb-3">Unpaid Orders</th>
                  <th className="pb-3">Total Outstanding Due</th>
                  <th className="pb-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {outstandingData.length === 0 ? (
                  <tr>
                    <td colSpan="6" className="py-12 text-center text-slate-400">
                      No outstanding balances found across active accounts.
                    </td>
                  </tr>
                ) : (
                  outstandingData.map((cust, idx) => (
                    <tr key={cust.customer_id || idx} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold text-slate-900">
                        {cust.customer_name || `Customer #${cust.customer_id}`}
                      </td>
                      <td className="py-3.5 text-slate-600">{cust.customer_phone || cust.phone || 'N/A'}</td>
                      <td className="py-3.5 font-medium text-sky-600">{cust.franchise_name || 'Central Support'}</td>
                      <td className="py-3.5 font-semibold text-slate-700">{cust.unpaid_orders_count ?? cust.orders_count ?? 1}</td>
                      <td className="py-3.5 font-bold text-rose-600">₹{parseFloat(cust.balance_due ?? cust.total_outstanding ?? 0).toFixed(2)}</td>
                      <td className="py-3.5 text-right">
                        <span className="rounded-md bg-amber-50 px-2 py-1 text-xs font-semibold text-amber-700">
                          Follow-up Required
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 4: DELIVERY PRICING BANDS */}
      {activeTab === 'delivery' && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
          <div className="flex items-center justify-between pb-4 border-b border-slate-100">
            <div>
              <h2 className="text-sm font-bold text-slate-900">Distance-Based Delivery Pricing Bands</h2>
              <p className="text-xs text-slate-500">Tiered distance rates calculated from fulfillment plant / franchise hubs</p>
            </div>
            <button
              onClick={fetchDeliveryBands}
              className="inline-flex items-center space-x-1 text-xs font-semibold text-sky-600 hover:text-sky-700"
            >
              <RefreshCw className="h-3.5 w-3.5" />
              <span>Refresh Bands</span>
            </button>
          </div>

          <div className="overflow-x-auto mt-4">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-3">Band Name</th>
                  <th className="pb-3">Distance Range (KM)</th>
                  <th className="pb-3">Base Delivery Fee</th>
                  <th className="pb-3">Per KM Surcharge</th>
                  <th className="pb-3">Active Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {deliveryBands.length === 0 ? (
                  <tr>
                    <td colSpan="5" className="py-12 text-center text-slate-400">
                      Standard delivery configuration active (₹30 base + ₹5/km beyond 5km).
                    </td>
                  </tr>
                ) : (
                  deliveryBands.map((band) => (
                    <tr key={band.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold text-slate-900">{band.name || `Band ${band.id}`}</td>
                      <td className="py-3.5 font-mono text-slate-700">{band.min_km || 0} km — {band.max_km || 'Any'} km</td>
                      <td className="py-3.5 font-bold text-emerald-600">₹{parseFloat(band.base_fee || 0).toFixed(2)}</td>
                      <td className="py-3.5 text-slate-600">₹{parseFloat(band.per_km_fee || 0).toFixed(2)} / km</td>
                      <td className="py-3.5">
                        <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[10px] font-semibold text-emerald-700">
                          Active
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Record Payment Modal */}
      {recordModalOpen && selectedInvoice && (
        <Modal
          isOpen={true}
          onClose={() => setRecordModalOpen(false)}
          title={`Record Payment — Invoice #${selectedInvoice.invoice_number || selectedInvoice.id}`}
        >
          <form onSubmit={handleRecordPayment} className="space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-slate-700">Amount Paid (₹)</label>
              <input
                type="number"
                step="0.01"
                required
                value={payAmount}
                onChange={(e) => setPayAmount(e.target.value)}
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Payment Mode</label>
              <select
                value={payMethod}
                onChange={(e) => setPayMethod(e.target.value)}
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              >
                <option value="CASH">Cash Collection</option>
                <option value="UPI">UPI / QR Code</option>
                <option value="BANK_TRANSFER">Bank NEFT / RTGS</option>
                <option value="CHEQUE">Cheque</option>
              </select>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Reference / UTR / Cheque Number</label>
              <input
                type="text"
                value={payRef}
                onChange={(e) => setPayRef(e.target.value)}
                placeholder="e.g. UPI Ref: 312389471"
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Collection Notes</label>
              <textarea
                rows={2}
                value={payNotes}
                onChange={(e) => setPayNotes(e.target.value)}
                placeholder="Received by cashier at delivery point"
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="flex justify-end space-x-2 pt-2">
              <button
                type="button"
                onClick={() => setRecordModalOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className="rounded-lg bg-emerald-600 px-4 py-2 font-semibold text-white hover:bg-emerald-500 disabled:opacity-50"
              >
                {isSubmitting ? 'Recording...' : 'Confirm Receipt'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Verify / Reject Txn Modal */}
      {txnActionModalOpen && selectedTxn && (
        <Modal
          isOpen={true}
          onClose={() => setTxnActionModalOpen(false)}
          title={`${txnActionType === 'verify' ? 'Approve Payment' : 'Reject Payment'} — TXN #${selectedTxn.id}`}
        >
          <form onSubmit={handleTxnActionSubmit} className="space-y-4 text-xs">
            <div className="rounded-lg bg-slate-50 p-3 border border-slate-200 space-y-1">
              <div><span className="text-slate-500">Party:</span> <span className="font-bold text-slate-900">{selectedTxn.user_name || selectedTxn.customer_name || 'Customer'}</span></div>
              <div><span className="text-slate-500">Amount:</span> <span className="font-bold text-emerald-600">₹{parseFloat(selectedTxn.amount || 0).toFixed(2)}</span></div>
              <div><span className="text-slate-500">Reference:</span> <span className="font-mono text-slate-800">{selectedTxn.reference_number || selectedTxn.transaction_id || 'N/A'}</span></div>
            </div>

            {txnActionType === 'reject' ? (
              <div>
                <label className="block font-semibold text-slate-700">Rejection Reason (Required)</label>
                <textarea
                  rows={3}
                  required
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  placeholder="State the reason (e.g. UTR not reflected in bank account, wrong transaction screenshot)..."
                  className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-rose-500 focus:outline-none"
                />
              </div>
            ) : (
              <p className="text-xs text-slate-600">
                Are you sure you want to approve this payment? This will update the invoice/order payment status to PAID and credit the customer's ledger.
              </p>
            )}

            <div className="flex justify-end space-x-2 pt-2">
              <button
                type="button"
                onClick={() => setTxnActionModalOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className={`rounded-lg px-4 py-2 font-semibold text-white disabled:opacity-50 ${
                  txnActionType === 'verify' ? 'bg-emerald-600 hover:bg-emerald-500' : 'bg-rose-600 hover:bg-rose-500'
                }`}
              >
                {isSubmitting ? 'Processing...' : txnActionType === 'verify' ? 'Confirm Approval' : 'Confirm Rejection'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
