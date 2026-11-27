import React, { useState, useEffect } from 'react';
import { 
  FileText, Plus, Search, RefreshCw, Download, CheckCircle2, 
  AlertCircle, Eye, User, Phone, Calendar, Edit, Trash2, Upload, File 
} from 'lucide-react';
import apiClient, { API_BASE_URL } from '../api/client';
import Modal from '../components/common/Modal';
import { useAuth } from '../context/AuthContext';

export default function Quotations() {
  const { hasPermission } = useAuth();
  const [quotations, setQuotations] = useState([]);
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedQuotation, setSelectedQuotation] = useState(null);
  const [sortBy, setSortBy] = useState('date_desc');
  const [franchises, setFranchises] = useState([]);
  const [selectedFranchiseId, setSelectedFranchiseId] = useState('');
  const [quotationStatus, setQuotationStatus] = useState('published');

  // Create Quotation State
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [customerName, setCustomerName] = useState('');
  const [customerPhone, setCustomerPhone] = useState('');
  const [customerEmail, setCustomerEmail] = useState('');
  const [deliveryAddress, setDeliveryAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [items, setItems] = useState([{ product_id: '', quantity: 10, unit_price: 20 }]);
  const [createPdfFile, setCreatePdfFile] = useState(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formError, setFormError] = useState('');

  // Edit Quotation State
  const [editingQuotation, setEditingQuotation] = useState(null);
  const [editTitle, setEditTitle] = useState('');
  const [editFranchiseId, setEditFranchiseId] = useState('');
  const [editProductId, setEditProductId] = useState('');
  const [editQuantityTier, setEditQuantityTier] = useState('');
  const [editUnitPrice, setEditUnitPrice] = useState('');
  const [editValidity, setEditValidity] = useState('');
  const [editNotes, setEditNotes] = useState('');
  const [editTerms, setEditTerms] = useState('');
  const [editStatus, setEditStatus] = useState('published');
  const [editPdfFile, setEditPdfFile] = useState(null);
  const [editRemovePdf, setEditRemovePdf] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [editError, setEditError] = useState('');

  // Quotation Accept / Reject Action
  const [actionLoading, setActionLoading] = useState(false);
  const [rejectPromptOpen, setRejectPromptOpen] = useState(false);
  const [rejectionReasonText, setRejectionReasonText] = useState('');

  const handleQuotationAction = async (quotationId, actionType, reason = '') => {
    setActionLoading(true);
    try {
      await apiClient.post(`/api/chat/quotations/${quotationId}/action/`, {
        action: actionType,
        rejection_reason: reason,
      });
      fetchQuotations();
      setSelectedQuotation((prev) => (prev ? { ...prev, status: actionType === 'accept' ? 'accepted' : 'rejected' } : null));
      setRejectPromptOpen(false);
      setRejectionReasonText('');
    } catch (err) {
      alert(err.response?.data?.message || err.response?.data?.error || err.message || 'Quotation action failed');
    } finally {
      setActionLoading(false);
    }
  };

  const fetchQuotations = async () => {
    try {
      setIsLoading(true);
      const [qRes, pRes, fRes] = await Promise.all([
        apiClient.get('/api/chat/quotations/'),
        apiClient.get('/api/products/').catch(() => ({ data: [] })),
        apiClient.get('/api/accounts/franchises/').catch(() => ({ data: [] })),
      ]);
      const qList = qRes.data?.quotations || qRes.data?.results || (Array.isArray(qRes.data) ? qRes.data : []);
      setQuotations(qList);
      const pList = pRes.data?.products || pRes.data?.results || (Array.isArray(pRes.data) ? pRes.data : []);
      setProducts(pList);
      const fList = fRes.data?.franchises || fRes.data?.results || (Array.isArray(fRes.data) ? fRes.data : []);
      setFranchises(fList);
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
      const firstItem = items[0] || {};
      const formData = new FormData();
      formData.append('title', customerName.trim() || 'Franchise Special Rate Quotation');
      formData.append('target_audience', 'franchise');
      if (selectedFranchiseId) formData.append('franchise', selectedFranchiseId);
      if (firstItem.product_id) formData.append('product', firstItem.product_id);
      formData.append('quantity_tier', `${firstItem.quantity || 10} Units`);
      formData.append('unit_price', parseFloat(firstItem.unit_price || 0));
      formData.append('total_price', totalCalculated);
      formData.append('final_amount', totalCalculated);
      formData.append('validity', 'Valid for 30 days from generation');
      formData.append('notes', notes.trim());
      formData.append('applicable_terms', deliveryAddress.trim() || 'Standard delivery, purity warranty, and franchise terms apply.');
      formData.append('status', quotationStatus);
      if (createPdfFile) {
        formData.append('pdf_file', createPdfFile);
      }

      await apiClient.post('/api/chat/quotations/', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      setIsCreateModalOpen(false);
      setCustomerName('');
      setSelectedFranchiseId('');
      setQuotationStatus('published');
      setCustomerPhone('');
      setCustomerEmail('');
      setDeliveryAddress('');
      setNotes('');
      setCreatePdfFile(null);
      fetchQuotations();
    } catch (err) {
      setFormError(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to create quotation');
    } finally {
      setIsSubmitting(false);
    }
  };

  const openEditModal = (q) => {
    setEditingQuotation(q);
    setEditTitle(q.title || '');
    setEditFranchiseId(q.franchise?.toString() || q.franchise_details?.id?.toString() || '');
    setEditProductId(q.product?.toString() || q.product_details?.id?.toString() || '');
    setEditQuantityTier(q.quantity_tier || '10 Units');
    setEditUnitPrice(q.unit_price?.toString() || '0');
    setEditValidity(q.validity || 'Valid for 30 days from generation');
    setEditNotes(q.notes || '');
    setEditTerms(q.applicable_terms || 'Standard delivery, purity warranty, and franchise terms apply.');
    setEditStatus(q.status?.toLowerCase() || 'published');
    setEditPdfFile(null);
    setEditRemovePdf(false);
    setEditError('');
  };

  const handleUpdateQuotation = async (e) => {
    e.preventDefault();
    if (!editingQuotation) return;
    setIsUpdating(true);
    setEditError('');

    try {
      const formData = new FormData();
      formData.append('title', editTitle.trim());
      formData.append('target_audience', 'franchise');
      formData.append('franchise', editFranchiseId || '');
      formData.append('product', editProductId || '');
      formData.append('quantity_tier', editQuantityTier.trim() || '10 Units');
      const uPrice = parseFloat(editUnitPrice) || 0;
      formData.append('unit_price', uPrice);

      const qtyMatch = editQuantityTier.match(/\d+/);
      const qty = qtyMatch ? parseInt(qtyMatch[0], 10) : 10;
      const total = qty * uPrice;
      formData.append('total_price', total);
      formData.append('final_amount', total);
      formData.append('validity', editValidity.trim() || 'Valid for 30 days from generation');
      formData.append('notes', editNotes.trim());
      formData.append('applicable_terms', editTerms.trim());
      formData.append('status', editStatus);

      if (editPdfFile) {
        formData.append('pdf_file', editPdfFile);
      } else if (editRemovePdf) {
        formData.append('pdf_file', '');
      }

      await apiClient.patch(`/api/chat/quotations/${editingQuotation.id}/`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });

      setEditingQuotation(null);
      if (selectedQuotation?.id === editingQuotation.id) {
        setSelectedQuotation(null);
      }
      fetchQuotations();
    } catch (err) {
      setEditError(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to update quotation');
    } finally {
      setIsUpdating(false);
    }
  };

  const handleDeleteQuotation = async (qId) => {
    if (!window.confirm(`Are you sure you want to delete quotation #${qId}? This action cannot be undone.`)) return;
    try {
      await apiClient.delete(`/api/chat/quotations/${qId}/`);
      if (selectedQuotation?.id === qId) setSelectedQuotation(null);
      fetchQuotations();
    } catch (err) {
      alert(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to delete quotation');
    }
  };

  const totalCalculated = items.reduce(
    (sum, it) => sum + (parseFloat(it.unit_price) || 0) * (parseInt(it.quantity) || 0),
    0
  );

  const parsePrice = (val) => {
    if (val === null || val === undefined) return 0;
    if (typeof val === 'number') return val;
    const clean = val.toString().replace(/[₹,\s]/g, '');
    const num = parseFloat(clean);
    return isNaN(num) ? 0 : num;
  };

  const filtered = quotations
    .filter((q) => {
      if (!search) return true;
      const term = search.toLowerCase();
      return (
        q.title?.toLowerCase().includes(term) ||
        q.customer_name?.toLowerCase().includes(term) ||
        q.franchise_name?.toLowerCase().includes(term) ||
        q.phone?.includes(term) ||
        q.id?.toString().includes(term) ||
        q.quotation_number?.toLowerCase().includes(term)
      );
    })
    .sort((a, b) => {
      if (sortBy === 'price_asc') {
        return parsePrice(a.total_price ?? a.total_amount) - parsePrice(b.total_price ?? b.total_amount);
      }
      if (sortBy === 'price_desc') {
        return parsePrice(b.total_price ?? b.total_amount) - parsePrice(a.total_price ?? a.total_amount);
      }
      if (sortBy === 'date_asc') {
        return new Date(a.created_at || 0) - new Date(b.created_at || 0);
      }
      return new Date(b.created_at || 0) - new Date(a.created_at || 0);
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
            Generate, edit, and track formal B2B and franchise pricing proposals with downloadable PDF attachments
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
            placeholder="Search quotation by franchise name, title, reference #, or customer..."
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
                <th className="pb-3">Target Franchise</th>
                <th className="pb-3">Title / Tier</th>
                <th className="pb-3">Product</th>
                <th className="pb-3">Quoted Amount</th>
                <th className="pb-3">Status</th>
                <th className="pb-3">Attachment</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="8" className="py-8 text-center text-slate-400">
                    No commercial quotations found.
                  </td>
                </tr>
              ) : (
                filtered.map((q) => {
                  const status = (q.status || 'PUBLISHED').toUpperCase();
                  const total = parseFloat(q.total_price ?? q.total_amount ?? q.final_amount ?? 0);
                  const hasPdf = Boolean(q.pdf_file);

                  return (
                    <tr key={q.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold text-sky-600">{q.quotation_number || `#${q.id}`}</td>
                      <td className="py-3.5 font-bold text-slate-900 max-w-[170px] truncate" title={q.franchise_name || 'All Franchises'}>
                        {q.franchise_name || 'All Franchises'}
                      </td>
                      <td className="py-3.5 text-slate-600 max-w-[180px] truncate" title={q.title}>
                        {q.title} ({q.quantity_tier || '1 Unit'})
                      </td>
                      <td className="py-3.5 text-slate-600">{q.product_details?.name || 'General'}</td>
                      <td className="py-3.5 font-bold text-slate-900">
                        ₹{total.toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                      </td>
                      <td className="py-3.5">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                          status === 'ACCEPTED'
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : status === 'REJECTED'
                              ? 'bg-rose-50 text-rose-700 border border-rose-200'
                              : status === 'EXPIRED'
                                ? 'bg-amber-50 text-amber-700 border border-amber-200'
                                : 'bg-sky-50 text-sky-700 border border-sky-200'
                        }`}>
                          {status}
                        </span>
                      </td>
                      <td className="py-3.5">
                        {hasPdf ? (
                          <span className="inline-flex items-center space-x-1 text-emerald-600 text-[11px] font-medium">
                            <File className="h-3 w-3" />
                            <span>Custom PDF</span>
                          </span>
                        ) : (
                          <span className="text-slate-400 text-[11px]">Auto PDF</span>
                        )}
                      </td>
                      <td className="py-3.5 text-right space-x-1.5 whitespace-nowrap">
                        <button
                          onClick={() => setSelectedQuotation(q)}
                          className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                        >
                          <Eye className="h-3.5 w-3.5" />
                          <span>View</span>
                        </button>

                        {hasPermission('billing', 'edit') && (
                          <button
                            onClick={() => openEditModal(q)}
                            className="inline-flex items-center space-x-1 rounded-md bg-amber-50 px-2.5 py-1 text-xs font-semibold text-amber-700 hover:bg-amber-100 border border-amber-200"
                          >
                            <Edit className="h-3.5 w-3.5" />
                            <span>Edit</span>
                          </button>
                        )}

                        <a
                          href={`${API_BASE_URL}/api/chat/quotations/${q.id}/pdf/?token=${localStorage.getItem('ww_access_token') || ''}`}
                          target="_blank"
                          rel="noreferrer"
                          className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2.5 py-1 text-xs font-semibold text-sky-700 hover:bg-sky-100 border border-sky-200"
                        >
                          <Download className="h-3.5 w-3.5" />
                          <span>PDF</span>
                        </a>

                        {hasPermission('billing', 'delete') && (
                          <button
                            onClick={() => handleDeleteQuotation(q.id)}
                            className="inline-flex items-center p-1 rounded-md text-slate-400 hover:text-rose-600 hover:bg-rose-50"
                            title="Delete Quotation"
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                          </button>
                        )}
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
          title={`Quotation #${selectedQuotation.quotation_number || selectedQuotation.id} Details`}
          maxWidth="max-w-xl"
        >
          <div className="space-y-4 text-xs">
            <div className="grid grid-cols-2 gap-4 rounded-xl bg-slate-50 p-4 border border-slate-100">
              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Target Franchise / Client</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">{selectedQuotation.franchise_name || selectedQuotation.customer_name || 'All Franchises'}</p>
                <p className="text-slate-600 mt-0.5">{selectedQuotation.phone || selectedQuotation.title}</p>
                {selectedQuotation.email && <p className="text-slate-500">{selectedQuotation.email}</p>}
              </div>

              <div>
                <p className="text-slate-400 font-semibold uppercase text-[10px]">Quotation Value</p>
                <p className="font-bold text-slate-900 mt-1 text-sm">
                  ₹{parseFloat(selectedQuotation.total_price ?? selectedQuotation.total_amount ?? selectedQuotation.final_amount ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </p>
                <p className="text-slate-500 mt-0.5">
                  Created: {selectedQuotation.created_at ? new Date(selectedQuotation.created_at).toLocaleString() : 'Recent'}
                </p>
                <p className="text-sky-700 font-medium mt-0.5">
                  Status: {(selectedQuotation.status || 'PUBLISHED').toUpperCase()}
                </p>
              </div>
            </div>

            {/* Custom Attached PDF banner if present */}
            {selectedQuotation.pdf_file && (
              <div className="rounded-xl border border-emerald-200 bg-emerald-50/70 p-3 flex items-center justify-between">
                <div className="flex items-center space-x-2">
                  <File className="h-4 w-4 text-emerald-600" />
                  <div>
                    <p className="font-semibold text-emerald-900">Custom PDF Attachment Uploaded</p>
                    <p className="text-[11px] text-emerald-700">Official contract document attached to this quotation</p>
                  </div>
                </div>
                <a
                  href={selectedQuotation.pdf_file}
                  target="_blank"
                  rel="noreferrer"
                  className="rounded-lg bg-emerald-600 px-3 py-1 text-[11px] font-semibold text-white hover:bg-emerald-500"
                >
                  View Attachment
                </a>
              </div>
            )}

            <div>
              <h4 className="font-bold text-slate-800 uppercase tracking-wider text-[11px] mb-2">Proposal Line Items & Rates</h4>
              <div className="rounded-xl border border-slate-200 overflow-hidden">
                <table className="w-full text-left">
                  <thead className="bg-slate-50 text-slate-500 font-semibold border-b border-slate-100">
                    <tr>
                      <th className="p-2.5">Product SKU</th>
                      <th className="p-2.5 text-center">Tier / Qty</th>
                      <th className="p-2.5 text-right">Unit Price</th>
                      <th className="p-2.5 text-right">Subtotal</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    {(selectedQuotation.items && selectedQuotation.items.length > 0) ? (
                      selectedQuotation.items.map((it, idx) => {
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
                      })
                    ) : (
                      <tr>
                        <td className="p-2.5 font-medium text-slate-800">
                          {selectedQuotation.product_details?.name || 'Standard Franchise Rate'}
                        </td>
                        <td className="p-2.5 text-center font-bold text-slate-900">
                          {selectedQuotation.quantity_tier || '10 Units'}
                        </td>
                        <td className="p-2.5 text-right text-slate-600">
                          ₹{parseFloat(selectedQuotation.unit_price || 0).toFixed(2)}
                        </td>
                        <td className="p-2.5 text-right font-bold text-slate-900">
                          ₹{parseFloat(selectedQuotation.total_price ?? selectedQuotation.final_amount ?? 0).toFixed(2)}
                        </td>
                      </tr>
                    )}
                  </tbody>
                </table>
              </div>
            </div>

            {selectedQuotation.notes && (
              <div className="rounded-lg bg-amber-50 p-3 text-amber-900 border border-amber-200">
                <p className="font-bold uppercase text-[10px]">Notes & Commercial Terms:</p>
                <p className="mt-0.5">{selectedQuotation.notes}</p>
              </div>
            )}

            {selectedQuotation.applicable_terms && (
              <div className="rounded-lg bg-slate-50 p-3 text-slate-700 border border-slate-200">
                <p className="font-bold uppercase text-[10px]">Applicable Policy & Delivery:</p>
                <p className="mt-0.5">{selectedQuotation.applicable_terms}</p>
              </div>
            )}

            {/* Accept / Reject Action Toolbar for Published Quotations */}
            {selectedQuotation.status?.toLowerCase() === 'published' && hasPermission('billing', 'edit') && (
              <div className="rounded-xl border border-sky-100 bg-sky-50/60 p-3.5 space-y-2">
                <p className="font-bold text-slate-800 text-[11px] uppercase tracking-wider">Proposal Response Action</p>
                <p className="text-slate-600 text-[11px]">
                  Authorize acceptance on behalf of party or record formal rejection with reason.
                </p>
                <div className="flex items-center space-x-2 pt-1">
                  <button
                    type="button"
                    disabled={actionLoading}
                    onClick={() => handleQuotationAction(selectedQuotation.id, 'accept')}
                    className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-600 px-3 py-1.5 font-semibold text-white hover:bg-emerald-500 disabled:opacity-50"
                  >
                    <CheckCircle2 className="h-3.5 w-3.5" />
                    <span>{actionLoading ? 'Processing...' : 'Accept Proposal'}</span>
                  </button>
                  <button
                    type="button"
                    disabled={actionLoading}
                    onClick={() => setRejectPromptOpen(true)}
                    className="inline-flex items-center space-x-1.5 rounded-lg bg-rose-50 border border-rose-200 px-3 py-1.5 font-semibold text-rose-700 hover:bg-rose-100 disabled:opacity-50"
                  >
                    <AlertCircle className="h-3.5 w-3.5" />
                    <span>Reject Proposal</span>
                  </button>
                </div>
              </div>
            )}

            <div className="flex justify-between items-center pt-3 border-t border-slate-100">
              <div className="flex space-x-2">
                <a
                  href={`${API_BASE_URL}/api/chat/quotations/${selectedQuotation.id}/pdf/?token=${localStorage.getItem('ww_access_token') || ''}`}
                  target="_blank"
                  rel="noreferrer"
                  className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3.5 py-2 font-semibold text-white hover:bg-sky-500"
                >
                  <Download className="h-4 w-4" />
                  <span>Download Official PDF</span>
                </a>

                {hasPermission('billing', 'edit') && (
                  <button
                    type="button"
                    onClick={() => {
                      const q = selectedQuotation;
                      setSelectedQuotation(null);
                      openEditModal(q);
                    }}
                    className="inline-flex items-center space-x-1.5 rounded-lg border border-amber-300 bg-amber-50 px-3 py-2 font-semibold text-amber-800 hover:bg-amber-100"
                  >
                    <Edit className="h-4 w-4" />
                    <span>Edit Quotation</span>
                  </button>
                )}
              </div>

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

      {/* Rejection Reason Modal */}
      {rejectPromptOpen && selectedQuotation && (
        <Modal
          isOpen={true}
          onClose={() => setRejectPromptOpen(false)}
          title={`Reject Quotation #${selectedQuotation.id}`}
        >
          <div className="space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-slate-700">Reason for Rejection (Required)</label>
              <textarea
                rows={3}
                required
                value={rejectionReasonText}
                onChange={(e) => setRejectionReasonText(e.target.value)}
                placeholder="State the reason (e.g. rate exceeds budget, packaging specifications adjusted, party chose alternate supplier)..."
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-rose-500 focus:outline-none"
              />
            </div>
            <div className="flex justify-end space-x-2 pt-2">
              <button
                type="button"
                onClick={() => setRejectPromptOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={actionLoading || !rejectionReasonText.trim()}
                onClick={() => handleQuotationAction(selectedQuotation.id, 'reject', rejectionReasonText.trim())}
                className="rounded-lg bg-rose-600 px-4 py-2 font-semibold text-white hover:bg-rose-500 disabled:opacity-50"
              >
                {actionLoading ? 'Recording...' : 'Confirm Rejection'}
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
                <label className="block font-semibold text-slate-700">Target Franchise * (Franchise Only)</label>
                <select
                  value={selectedFranchiseId}
                  onChange={(e) => setSelectedFranchiseId(e.target.value)}
                  className="mt-1 block w-full max-w-full truncate rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="">All Franchises (General Policy)</option>
                  {franchises.map((f) => (
                    <option key={f.id} value={f.id}>
                      {f.business_name} ({f.dealer_code || f.city || ''})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Publication Status</label>
                <select
                  value={quotationStatus}
                  onChange={(e) => setQuotationStatus(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="published">Published (Visible to Franchise)</option>
                  <option value="draft">Draft (Saved Internally)</option>
                </select>
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Quotation Title / Reference</label>
                <input
                  type="text"
                  required
                  value={customerName}
                  onChange={(e) => setCustomerName(e.target.value)}
                  placeholder="e.g. Special Jar Rate Contract Q1"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Applicable Terms & Delivery Notes</label>
                <input
                  type="text"
                  value={deliveryAddress}
                  onChange={(e) => setDeliveryAddress(e.target.value)}
                  placeholder="e.g. Standard delivery, purity warranty, and franchise terms apply."
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

            {/* Custom Quotation PDF Upload */}
            <div className="rounded-xl border border-dashed border-slate-300 p-3 bg-slate-50/50">
              <label className="block font-semibold text-slate-700 mb-1">
                Attach Custom Quotation PDF (Optional)
              </label>
              <div className="flex items-center space-x-3">
                <input
                  type="file"
                  accept="application/pdf"
                  onChange={(e) => setCreatePdfFile(e.target.files?.[0] || null)}
                  className="text-xs text-slate-600 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-semibold file:bg-sky-50 file:text-sky-700 hover:file:bg-sky-100"
                />
                {createPdfFile && (
                  <span className="text-[11px] text-emerald-600 font-medium">
                    {createPdfFile.name} ({(createPdfFile.size / 1024).toFixed(1)} KB)
                  </span>
                )}
              </div>
              <p className="text-[10px] text-slate-400 mt-1">
                If provided, this PDF will replace the standard auto-generated document for client download.
              </p>
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

      {/* Edit Quotation Modal */}
      {editingQuotation && (
        <Modal
          isOpen={true}
          onClose={() => setEditingQuotation(null)}
          title={`Edit Quotation #${editingQuotation.quotation_number || editingQuotation.id}`}
          maxWidth="max-w-2xl"
        >
          <form onSubmit={handleUpdateQuotation} className="space-y-4 text-xs">
            {editError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-800 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{editError}</span>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Target Franchise *</label>
                <select
                  value={editFranchiseId}
                  onChange={(e) => setEditFranchiseId(e.target.value)}
                  className="mt-1 block w-full max-w-full truncate rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="">All Franchises (General Policy)</option>
                  {franchises.map((f) => (
                    <option key={f.id} value={f.id}>
                      {f.business_name} ({f.dealer_code || f.city || ''})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Publication Status</label>
                <select
                  value={editStatus}
                  onChange={(e) => setEditStatus(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="published">Published (Visible to Franchise)</option>
                  <option value="draft">Draft (Saved Internally)</option>
                  <option value="accepted">Accepted</option>
                  <option value="rejected">Rejected</option>
                  <option value="expired">Expired</option>
                </select>
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Quotation Title / Reference</label>
                <input
                  type="text"
                  required
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  placeholder="e.g. Special Jar Rate Contract Q1"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Product SKU</label>
                <select
                  value={editProductId}
                  onChange={(e) => {
                    setEditProductId(e.target.value);
                    const prod = products.find((p) => p.id.toString() === e.target.value.toString());
                    if (prod && !editUnitPrice) {
                      setEditUnitPrice(prod.price || '0');
                    }
                  }}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="">General Proposal / Custom</option>
                  {products.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name} (Stock: {p.stock ?? p.current_stock ?? 0})
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Quantity Tier / MOQ Specification</label>
                <input
                  type="text"
                  required
                  value={editQuantityTier}
                  onChange={(e) => setEditQuantityTier(e.target.value)}
                  placeholder="e.g. 50 Units, 100 Cartons"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Unit Price (₹)</label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={editUnitPrice}
                  onChange={(e) => setEditUnitPrice(e.target.value)}
                  placeholder="0.00"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Validity</label>
                <input
                  type="text"
                  value={editValidity}
                  onChange={(e) => setEditValidity(e.target.value)}
                  placeholder="e.g. Valid for 30 days from generation"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Applicable Terms & Delivery Notes</label>
                <input
                  type="text"
                  value={editTerms}
                  onChange={(e) => setEditTerms(e.target.value)}
                  placeholder="e.g. Standard delivery, purity warranty, and franchise terms apply."
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Commercial Notes / Payment Terms</label>
                <textarea
                  rows="2"
                  value={editNotes}
                  onChange={(e) => setEditNotes(e.target.value)}
                  placeholder="e.g. 50% advance on order confirmation, remaining on delivery"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            {/* Custom Quotation PDF Upload / Replacement */}
            <div className="rounded-xl border border-dashed border-slate-300 p-3 bg-slate-50/50 space-y-2">
              <label className="block font-semibold text-slate-700">
                Quotation PDF Document
              </label>

              {editingQuotation.pdf_file && !editRemovePdf && (
                <div className="flex items-center justify-between bg-white rounded-lg p-2 border border-slate-200">
                  <div className="flex items-center space-x-2">
                    <File className="h-4 w-4 text-emerald-600" />
                    <span className="text-xs text-slate-700 font-medium">Currently Attached PDF Document</span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <a
                      href={editingQuotation.pdf_file}
                      target="_blank"
                      rel="noreferrer"
                      className="text-xs text-sky-600 hover:underline font-semibold"
                    >
                      View
                    </a>
                    <button
                      type="button"
                      onClick={() => setEditRemovePdf(true)}
                      className="text-xs text-rose-600 hover:underline"
                    >
                      Remove
                    </button>
                  </div>
                </div>
              )}

              {editRemovePdf && (
                <div className="rounded bg-rose-50 p-2 text-xs text-rose-700 flex justify-between items-center">
                  <span>Attached PDF will be removed on saving. Auto-generated PDF will be used instead.</span>
                  <button
                    type="button"
                    onClick={() => setEditRemovePdf(false)}
                    className="font-semibold underline ml-2"
                  >
                    Undo
                  </button>
                </div>
              )}

              <div>
                <p className="text-[11px] text-slate-500 mb-1">
                  {editingQuotation.pdf_file ? 'Upload replacement PDF:' : 'Attach custom PDF:'}
                </p>
                <input
                  type="file"
                  accept="application/pdf"
                  onChange={(e) => {
                    setEditPdfFile(e.target.files?.[0] || null);
                    if (e.target.files?.[0]) setEditRemovePdf(false);
                  }}
                  className="text-xs text-slate-600 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-semibold file:bg-sky-50 file:text-sky-700 hover:file:bg-sky-100"
                />
              </div>
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setEditingQuotation(null)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isUpdating}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isUpdating ? 'Saving Changes...' : 'Save & Update Quotation'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
