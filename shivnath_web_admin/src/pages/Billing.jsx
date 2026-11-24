import React, { useState, useEffect } from 'react';
import { Receipt, Search, CheckCircle, Download, CreditCard, RefreshCw, AlertCircle, FileText } from 'lucide-react';
import StatusBadge from '../components/common/StatusBadge';
import Modal from '../components/common/Modal';
import apiClient, { API_BASE_URL } from '../api/client';
import { useAuth } from '../context/AuthContext';
import { useRealTime } from '../context/RealTimeContext';

export default function Billing() {
  const { hasPermission } = useAuth();
  const { subscribe } = useRealTime();

  const [invoices, setInvoices] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedInvoice, setSelectedInvoice] = useState(null);

  // Manual payment recording modal
  const [recordModalOpen, setRecordModalOpen] = useState(false);
  const [payAmount, setPayAmount] = useState('');
  const [payMethod, setPayMethod] = useState('CASH');
  const [payRef, setPayRef] = useState('');
  const [payNotes, setPayNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchInvoices = async () => {
    try {
      setIsLoading(true);
      const res = await apiClient.get('/api/billing/invoices/?page_size=50');
      setInvoices(res.data?.results || res.data?.invoices || res.data || []);
    } catch (err) {
      console.warn('Invoices fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchInvoices();

    const unsubPay = subscribe('payment.recorded', () => fetchInvoices());
    const unsubVer = subscribe('payment.verified', () => fetchInvoices());

    return () => {
      unsubPay();
      unsubVer();
    };
  }, [subscribe]);

  const handleRecordPayment = async (e) => {
    e.preventDefault();
    if (!selectedInvoice || !payAmount) return;
    setIsSubmitting(true);

    try {
      await apiClient.post(`/api/billing/invoices/${selectedInvoice.id}/record-payment/`, {
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
      alert(err.response?.data?.message || err.message || 'Failed to record payment');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDownloadReceipt = (invoiceId) => {
    const token = localStorage.getItem('ww_access_token');
    window.open(`${API_BASE_URL}/api/billing/invoices/${invoiceId}/thermal-receipt/?token=${token}`, '_blank');
  };

  const filtered = invoices.filter((inv) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      inv.id?.toString().includes(q) ||
      inv.invoice_number?.toLowerCase().includes(q) ||
      inv.customer_name?.toLowerCase().includes(q) ||
      inv.franchise_name?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Billing, Invoices & Collections</h1>
          <p className="text-sm text-slate-500">
            GST-compliant invoices, collections verification, and receipt downloads
          </p>
        </div>

        <button
          onClick={fetchInvoices}
          className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
        >
          <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Search Toolbar */}
      <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="relative w-full">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by invoice number, customer, or dealer..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>
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
                <th className="pb-3">Date</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="8" className="py-12 text-center text-slate-400">
                    No billing records found.
                  </td>
                </tr>
              ) : (
                filtered.map((inv) => {
                  const total = parseFloat(inv.grand_total ?? inv.total_amount ?? inv.total ?? 0);
                  const paid = parseFloat(inv.amount_paid ?? inv.paid ?? inv.paid_amount ?? 0);
                  const balance = Math.max(0, total - paid);
                  return (
                    <tr key={inv.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold font-mono text-sky-600">
                        {inv.invoice_number || `INV-${inv.id}`}
                      </td>
                      <td className="py-3.5 font-medium text-slate-900">
                        {inv.customer_name || inv.franchise_name || inv.billed_to_name || 'Retail Party'}
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
                      <td className="py-3.5 text-right space-x-2">
                        {hasPermission('billing', 'edit') && balance > 0 && (
                          <button
                            onClick={() => {
                              setSelectedInvoice(inv);
                              setPayAmount(balance.toString());
                              setRecordModalOpen(true);
                            }}
                            className="inline-flex items-center space-x-1 rounded-md bg-emerald-50 px-2 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-100"
                          >
                            <CreditCard className="h-3.5 w-3.5" />
                            <span>Collect</span>
                          </button>
                        )}
                        <button
                          onClick={() => handleDownloadReceipt(inv.id)}
                          className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                        >
                          <Download className="h-3.5 w-3.5" />
                          <span>Receipt</span>
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
    </div>
  );
}
