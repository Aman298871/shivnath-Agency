import React, { useState, useEffect } from 'react';
import { FileText, Plus, Search, RefreshCw, Download, CheckCircle2, AlertCircle, Eye, User, Phone, Calendar } from 'lucide-react';
import apiClient from '../api/client';
import Modal from '../components/common/Modal';
import { useAuth } from '../context/AuthContext';

export default function Quotations() {
  const { hasPermission } = useAuth();
  const [quotations, setQuotations] = useState([]);
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedQuotation, setSelectedQuotation] = useState(null);

  // Create Quotation State
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [customerName, setCustomerName] = useState('');
  const [customerPhone, setCustomerPhone] = useState('');
  const [customerEmail, setCustomerEmail] = useState('');
  const [deliveryAddress, setDeliveryAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [items, setItems] = useState([{ product_id: '', quantity: 10, unit_price: 20 }]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  const fetchQuotations = async () => {
    try {
      setIsLoading(true);
      const [qRes, pRes] = await Promise.all([
        apiClient.get('/api/chat/quotations/'),
        apiClient.get('/api/products/').catch(() => ({ data: [] })),
      ]);
      const qList = qRes.data?.quotations || qRes.data?.results || (Array.isArray(qRes.data) ? qRes.data : []);
      setQuotations(qList);
      const pList = pRes.data?.products || pRes.data?.results || (Array.isArray(pRes.data) ? pRes.data : []);
      setProducts(pList);
    } catch (err) {
      console.warn('Quotations fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchQuotations();
  }, []);

  const handleProductChange = (index, prodId) => {
    const newItems = [...items];
    newItems[index].product_id = prodId;
    const prod = products.find((p) => p.id.toString() === prodId.toString());
    if (prod) {
      newItems[index].unit_price = parseFloat(prod.price || 0);
    }
    setItems(newItems);
  };

  const handleQuantityChange = (index, qty) => {
    const newItems = [...items];
    newItems[index].quantity = parseInt(qty || 1, 10);
    setItems(newItems);
  };

  const handleUnitPriceChange = (index, price) => {
    const newItems = [...items];
    newItems[index].unit_price = parseFloat(price || 0);
    setItems(newItems);
  };

  const addItemRow = () => {
    setItems([...items, { product_id: products[0]?.id?.toString() || '', quantity: 10, unit_price: products[0]?.price || 20 }]);
  };

  const removeItemRow = (index) => {
    if (items.length === 1) return;
    setItems(items.filter((_, i) => i !== index));
  };

  const handleCreateQuotation = async (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    setFormError('');

    try {
      const payload = {
        customer_name: customerName.trim(),
        phone: customerPhone.trim(),
        email: customerEmail.trim(),
        delivery_address: deliveryAddress.trim(),
        notes: notes.trim(),
        items: items.map((it) => ({
          product_id: parseInt(it.product_id || products[0]?.id, 10),
          quantity: parseInt(it.quantity, 10),
          unit_price: parseFloat(it.unit_price),
        })),
      };

      await apiClient.post('/api/chat/quotations/', payload);
      setIsCreateModalOpen(false);
      setCustomerName('');
      setCustomerPhone('');
      setCustomerEmail('');
      setDeliveryAddress('');
      setNotes('');
      fetchQuotations();
    } catch (err) {
      setFormError(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to create quotation');
    } finally {
      setIsSubmitting(false);
    }
  };

  const totalCalculated = items.reduce(
    (sum, it) => sum + (parseFloat(it.unit_price) || 0) * (parseInt(it.quantity) || 0),
    0
  );

  const filtered = quotations.filter((q) => {
    if (!search) return true;
    const term = search.toLowerCase();
    return (
      q.customer_name?.toLowerCase().includes(term) ||
      q.phone?.includes(term) ||
      q.id?.toString().includes(term)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">
            Quotations & Estimates
          </h1>
          <p className="text-sm text-slate-500">
            Generate formal B2B and institutional pricing proposals with downloadable PDF invoices
          </p>
        </div>

        <div className="flex items-center space-x-2">
          {hasPermission('billing', 'edit') && (
            <button
              onClick={() => setIsCreateModalOpen(true)}
              className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
            >
              <Plus className="h-4 w-4" />
              <span>Create Quotation</span>
            </button>
          )}

          <button
            onClick={fetchQuotations}
            className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
          >
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Search Toolbar */}
      <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="relative w-full">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search quotation by customer name, phone, or quotation #..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>
      </div>

      {/* Quotations Table */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Quotation #</th>
                <th className="pb-3">Customer / Organization</th>
                <th className="pb-3">Contact</th>
                <th className="pb-3">Items / SKUs</th>
                <th className="pb-3">Total Value</th>
                <th className="pb-3">Status</th>
                <th className="pb-3">Date</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="8" className="py-12 text-center text-slate-400">
                    No quotations found.
                  </td>
                </tr>
              ) : (
                filtered.map((q) => {
                  const total = parseFloat(q.total_price ?? q.total_amount ?? q.grand_total ?? 0);
                  const itemCount = q.items?.length || 1;
                  const status = (q.status || 'SENT').toUpperCase();

                  return (
                    <tr key={q.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold text-sky-600">#{q.id}</td>
                      <td className="py-3.5 font-bold text-slate-900">{q.customer_name || 'Prospect'}</td>
                      <td className="py-3.5 text-slate-600">{q.phone || '—'}</td>
                      <td className="py-3.5 text-slate-600">{itemCount} item(s)</td>
                      <td className="py-3.5 font-bold text-slate-900">
                        ₹{total.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                      </td>
                      <td className="py-3.5">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                          status === 'ACCEPTED'
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : status === 'REJECTED'
                            ? 'bg-rose-50 text-rose-700 border border-rose-200'
                            : 'bg-sky-50 text-sky-700 border border-sky-200'
                        }`}>
                          {status}
                        </span>
                      </td>
                      <td className="py-3.5 text-slate-500">
                        {q.created_at ? new Date(q.created_at).toLocaleDateString() : 'Today'}
                      </td>
                      <td className="py-3.5 text-right space-x-1.5 whitespace-nowrap">
                        <button
                          onClick={() => setSelectedQuotation(q)}
                          className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                        >
                          <Eye className="h-3.5 w-3.5" />
                          <span>View</span>
                        </button>

                        <a
                          href={`http://127.0.0.1:8000/api/chat/quotations/${q.id}/pdf/`}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2.5 py-1 text-xs font-semibold text-sky-700 hover:bg-sky-100 border border-sky-200"
                        >
                          <Download className="h-3.5 w-3.5" />
                          <span>PDF</span>
                        </a>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Quotation Detail Modal */}
      {selectedQuotation && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedQuotation(null)}
          title={`Quotation #${selectedQuotation.id} Details`}
          maxWidth="max-w-xl"
        >
          <div className="space-y-4 text-xs">
            <div className="grid grid-cols-2 gap-4 rounded-xl bg-slate-50 p-4 border border-slate-100">
              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Client / Prospect</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">{selectedQuotation.customer_name}</p>
                <p className="text-slate-600 mt-0.5">{selectedQuotation.phone}</p>
                {selectedQuotation.email && <p className="text-slate-500">{selectedQuotation.email}</p>}
              </div>

              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Quotation Value</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">
                  ₹{parseFloat(selectedQuotation.total_price ?? selectedQuotation.total_amount ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </p>
                <p className="text-slate-500 mt-0.5">
                  Created: {selectedQuotation.created_at ? new Date(selectedQuotation.created_at).toLocaleString() : 'Recent'}
                </p>
              </div>
            </div>

            <div>
              <h4 className="font-bold text-slate-800 uppercase tracking-wider text-[11px] mb-2">Proposal Line Items</h4>
              <div className="rounded-xl border border-slate-200 overflow-hidden">
                <table className="w-full text-left">
                  <thead className="bg-slate-50 text-slate-500 font-semibold border-b border-slate-100">
                    <tr>
                      <th className="p-2.5">Product SKU</th>
                      <th className="p-2.5 text-center">Qty</th>
                      <th className="p-2.5 text-right">Unit Price</th>
                      <th className="p-2.5 text-right">Subtotal</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {(selectedQuotation.items || []).map((it, idx) => {
                      const unitP = parseFloat(it.unit_price || 0);
                      const qty = parseInt(it.quantity || 1, 10);
                      const sub = parseFloat(it.total_price || unitP * qty);
                      return (
                        <tr key={idx}>
                          <td className="p-2.5 font-medium text-slate-800">{it.product_name || `SKU #${it.product_id}`}</td>
                          <td className="p-2.5 text-center font-bold text-slate-900">{qty}</td>
                          <td className="p-2.5 text-right text-slate-600">₹{unitP.toFixed(2)}</td>
                          <td className="p-2.5 text-right font-bold text-slate-900">₹{sub.toFixed(2)}</td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>

            {selectedQuotation.notes && (
              <div className="rounded-lg bg-amber-50 p-3 text-amber-900 border border-amber-200">
                <p className="font-bold uppercase text-[10px]">Notes & Terms:</p>
                <p className="mt-0.5">{selectedQuotation.notes}</p>
              </div>
            )}

            <div className="flex justify-between items-center pt-3 border-t border-slate-100">
              <a
                href={`http://127.0.0.1:8000/api/chat/quotations/${selectedQuotation.id}/pdf/`}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3.5 py-2 font-semibold text-white hover:bg-sky-500"
              >
                <Download className="h-4 w-4" />
                <span>Download Official PDF</span>
              </a>

              <button
                type="button"
                onClick={() => setSelectedQuotation(null)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Close
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* Create Quotation Modal */}
      {isCreateModalOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsCreateModalOpen(false)}
          title="Create New Commercial Quotation"
          maxWidth="max-w-2xl"
        >
          <form onSubmit={handleCreateQuotation} className="space-y-4 text-xs">
            {formError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-800 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{formError}</span>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Client / Organization Name</label>
                <input
                  type="text"
                  required
                  value={customerName}
                  onChange={(e) => setCustomerName(e.target.value)}
                  placeholder="e.g. Raipur Club & Banquets"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Contact Phone Number</label>
                <input
                  type="text"
                  required
                  value={customerPhone}
                  onChange={(e) => setCustomerPhone(e.target.value)}
                  placeholder="e.g. 9826100000"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Delivery Address</label>
                <input
                  type="text"
                  value={deliveryAddress}
                  onChange={(e) => setDeliveryAddress(e.target.value)}
                  placeholder="Delivery address or venue details"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            {/* Line items dynamic builder */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h4 className="font-bold text-slate-800 uppercase tracking-wider text-[11px]">Proposed SKUs & Pricing</h4>
                <button
                  type="button"
                  onClick={addItemRow}
                  className="inline-flex items-center space-x-1 rounded bg-slate-100 px-2 py-1 text-[11px] font-semibold text-slate-700 hover:bg-slate-200"
                >
                  <Plus className="h-3 w-3" />
                  <span>Add SKU Row</span>
                </button>
              </div>

              <div className="space-y-2">
                {items.map((it, idx) => (
                  <div key={idx} className="flex items-center space-x-2">
                    <select
                      value={it.product_id}
                      onChange={(e) => handleProductChange(idx, e.target.value)}
                      className="flex-1 rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs focus:border-sky-500 focus:outline-none"
                    >
                      <option value="">Select Product SKU</option>
                      {products.map((p) => (
                        <option key={p.id} value={p.id}>
                          {p.name} (Stock: {p.stock ?? p.current_stock ?? 0})
                        </option>
                      ))}
                    </select>

                    <input
                      type="number"
                      min="1"
                      value={it.quantity}
                      onChange={(e) => handleQuantityChange(idx, e.target.value)}
                      placeholder="Qty"
                      className="w-20 rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs text-center focus:border-sky-500 focus:outline-none"
                    />

                    <input
                      type="number"
                      step="0.01"
                      value={it.unit_price}
                      onChange={(e) => handleUnitPriceChange(idx, e.target.value)}
                      placeholder="₹ Unit Price"
                      className="w-28 rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs text-right focus:border-sky-500 focus:outline-none"
                    />

                    <span className="w-28 text-right font-bold text-slate-900 text-xs">
                      ₹{((it.quantity || 0) * (it.unit_price || 0)).toFixed(2)}
                    </span>

                    {items.length > 1 && (
                      <button
                        type="button"
                        onClick={() => removeItemRow(idx)}
                        className="p-1 text-slate-400 hover:text-rose-600"
                      >
                        ✕
                      </button>
                    )}
                  </div>
                ))}
              </div>

              <div className="mt-3 flex justify-end font-bold text-slate-900 text-sm">
                <span>Grand Total: ₹{totalCalculated.toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
              </div>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Commercial Notes / Payment Terms</label>
              <textarea
                rows="2"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="e.g. 50% advance on order confirmation, remaining on delivery"
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsCreateModalOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSubmitting ? 'Generating...' : 'Save & Issue Quotation'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
