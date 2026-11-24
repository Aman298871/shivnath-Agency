import React, { useState, useEffect } from 'react';
import { Factory, Package, Layers, Plus, RefreshCw, CheckCircle2, AlertCircle, Clock, Truck, Check } from 'lucide-react';
import apiClient from '../api/client';
import Modal from '../components/common/Modal';
import { useAuth } from '../context/AuthContext';

export default function PlantStock() {
  const { hasPermission } = useAuth();
  const [activeTab, setActiveTab] = useState('batches'); // 'batches' | 'requests' | 'raw_materials'

  // Data States
  const [batches, setBatches] = useState([]);
  const [stockRequests, setStockRequests] = useState([]);
  const [rawMaterials, setRawMaterials] = useState([]);
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // New Batch Modal State
  const [isBatchModalOpen, setIsBatchModalOpen] = useState(false);
  const [batchNumber, setBatchNumber] = useState('');
  const [batchProductId, setBatchProductId] = useState('');
  const [batchQuantity, setBatchQuantity] = useState(500);
  const [batchExpiryDays, setBatchExpiryDays] = useState(180);
  const [isSubmittingBatch, setIsSubmittingBatch] = useState(false);
  const [batchError, setBatchError] = useState('');

  // Stock Request Dispatch State
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [dispatchNotes, setDispatchNotes] = useState('');
  const [isDispatching, setIsDispatching] = useState(false);

  const fetchPlantData = async () => {
    try {
      setIsLoading(true);
      const [batchesRes, reqRes, rawRes, prodsRes] = await Promise.all([
        apiClient.get('/api/inventory/production-batches/').catch(() => ({ data: [] })),
        apiClient.get('/api/inventory/dealer-requests/').catch(() => ({ data: [] })),
        apiClient.get('/api/inventory/raw-materials/').catch(() => ({ data: [] })),
        apiClient.get('/api/products/').catch(() => ({ data: [] })),
      ]);

      setBatches(batchesRes.data?.batches || batchesRes.data?.results || (Array.isArray(batchesRes.data) ? batchesRes.data : []));
      setStockRequests(reqRes.data?.requests || reqRes.data?.results || (Array.isArray(reqRes.data) ? reqRes.data : []));
      setRawMaterials(rawRes.data?.raw_materials || rawRes.data?.results || (Array.isArray(rawRes.data) ? rawRes.data : []));
      const pList = prodsRes.data?.products || prodsRes.data?.results || (Array.isArray(prodsRes.data) ? prodsRes.data : []);
      setProducts(pList);
      if (pList.length > 0 && !batchProductId) {
        setBatchProductId(pList[0].id.toString());
      }
    } catch (err) {
      console.warn('Plant Stock fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchPlantData();
  }, []);

  const openNewBatchModal = () => {
    const todayStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const rand = Math.floor(100 + Math.random() * 900);
    setBatchNumber(`BATCH-${todayStr}-${rand}`);
    setBatchQuantity(500);
    setBatchExpiryDays(180);
    setBatchError('');
    setIsBatchModalOpen(true);
  };

  const handleCreateBatch = async (e) => {
    e.preventDefault();
    setIsSubmittingBatch(true);
    setBatchError('');

    try {
      const expDate = new Date();
      expDate.setDate(expDate.getDate() + parseInt(batchExpiryDays, 10));

      await apiClient.post('/api/inventory/production-batches/', {
        batch_number: batchNumber.trim(),
        product_id: parseInt(batchProductId, 10),
        quantity_manufactured: parseInt(batchQuantity, 10),
        expiry_date: expDate.toISOString().slice(0, 10),
      });

      setIsBatchModalOpen(false);
      fetchPlantData();
    } catch (err) {
      setBatchError(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to record batch');
    } finally {
      setIsSubmittingBatch(false);
    }
  };

  const handleDispatchStockRequest = async () => {
    if (!selectedRequest) return;
    setIsDispatching(true);

    try {
      await apiClient.post(`/api/inventory/dealer-requests/${selectedRequest.id}/dispatch/`, {
        notes: dispatchNotes || 'Stock dispatched from Central Bottling Plant',
      });
      setSelectedRequest(null);
      setDispatchNotes('');
      fetchPlantData();
    } catch (err) {
      alert(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to dispatch request');
    } finally {
      setIsDispatching(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">
            Plant Operations & Stock Control
          </h1>
          <p className="text-sm text-slate-500">
            Monitor bottling production runs, raw materials inventory & dealer warehouse replenishment
          </p>
        </div>

        <div className="flex items-center space-x-2">
          {hasPermission('inventory', 'edit') && (
            <button
              onClick={openNewBatchModal}
              className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
            >
              <Plus className="h-4 w-4" />
              <span>Record Production Batch</span>
            </button>
          )}

          <button
            onClick={fetchPlantData}
            className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
          >
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex space-x-2 border-b border-slate-200 text-xs font-semibold">
        <button
          onClick={() => setActiveTab('batches')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 ${
            activeTab === 'batches'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Factory className="h-4 w-4" />
          <span>Production Batches ({batches.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('requests')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 ${
            activeTab === 'requests'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Truck className="h-4 w-4" />
          <span>Dealer Stock Requests ({stockRequests.filter(r => r.status === 'PENDING').length} pending)</span>
        </button>

        <button
          onClick={() => setActiveTab('raw_materials')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 ${
            activeTab === 'raw_materials'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Layers className="h-4 w-4" />
          <span>Raw Materials Inventory</span>
        </button>
      </div>

      {/* TAB 1: PRODUCTION BATCHES */}
      {activeTab === 'batches' && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-3">Batch Number</th>
                  <th className="pb-3">Product Name</th>
                  <th className="pb-3">Manufactured</th>
                  <th className="pb-3">Available Plant Stock</th>
                  <th className="pb-3">Mfg Date</th>
                  <th className="pb-3">Expiry Date</th>
                  <th className="pb-3">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {batches.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="py-12 text-center text-slate-400">
                      No production batches recorded yet.
                    </td>
                  </tr>
                ) : (
                  batches.map((b) => {
                    const status = (b.status || 'ACTIVE').toUpperCase();
                    const isExhausted = (b.quantity_remaining_company || 0) <= 0;

                    return (
                      <tr key={b.id} className="hover:bg-slate-50/80 transition-colors">
                        <td className="py-3.5 font-mono font-bold text-sky-600">{b.batch_number}</td>
                        <td className="py-3.5 font-bold text-slate-900">{b.product_name || `Product #${b.product}`}</td>
                        <td className="py-3.5 text-slate-700">{b.quantity_manufactured} units</td>
                        <td className="py-3.5 font-bold text-emerald-600">
                          {b.quantity_remaining_company ?? b.remaining_quantity ?? b.quantity_manufactured} units
                        </td>
                        <td className="py-3.5 text-slate-500">
                          {b.production_date ? new Date(b.production_date).toLocaleDateString() : 'Today'}
                        </td>
                        <td className="py-3.5 text-slate-500">
                          {b.expiry_date ? new Date(b.expiry_date).toLocaleDateString() : '—'}
                        </td>
                        <td className="py-3.5">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                            isExhausted
                              ? 'bg-slate-100 text-slate-600'
                              : status === 'ACTIVE'
                              ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                              : 'bg-rose-50 text-rose-700 border border-rose-200'
                          }`}>
                            {isExhausted ? 'EXHAUSTED' : status}
                          </span>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: DEALER STOCK REQUESTS */}
      {activeTab === 'requests' && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-3">Request #</th>
                  <th className="pb-3">Franchise Dealer</th>
                  <th className="pb-3">Requested SKU</th>
                  <th className="pb-3">Quantity</th>
                  <th className="pb-3">Status</th>
                  <th className="pb-3">Request Date</th>
                  <th className="pb-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {stockRequests.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="py-12 text-center text-slate-400">
                      No dealer stock requests found.
                    </td>
                  </tr>
                ) : (
                  stockRequests.map((req) => {
                    const isPending = (req.status || 'PENDING').toUpperCase() === 'PENDING';

                    return (
                      <tr key={req.id} className="hover:bg-slate-50/80 transition-colors">
                        <td className="py-3.5 font-bold text-sky-600">#{req.id}</td>
                        <td className="py-3.5 font-bold text-slate-900">{req.dealer_name || `Dealer #${req.dealer}`}</td>
                        <td className="py-3.5 text-slate-700">{req.product_name || `Product #${req.product}`}</td>
                        <td className="py-3.5 font-bold text-slate-900">{req.quantity_requested || req.quantity} units</td>
                        <td className="py-3.5">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                            isPending
                              ? 'bg-amber-50 text-amber-700 border border-amber-200'
                              : req.status === 'DISPATCHED'
                              ? 'bg-purple-50 text-purple-700 border border-purple-200'
                              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          }`}>
                            {req.status || 'PENDING'}
                          </span>
                        </td>
                        <td className="py-3.5 text-slate-500">
                          {req.created_at ? new Date(req.created_at).toLocaleDateString() : 'Today'}
                        </td>
                        <td className="py-3.5 text-right">
                          {isPending && hasPermission('inventory', 'edit') && (
                            <button
                              onClick={() => setSelectedRequest(req)}
                              className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2.5 py-1 text-xs font-semibold text-sky-700 hover:bg-sky-100 border border-sky-200"
                            >
                              <Truck className="h-3.5 w-3.5" />
                              <span>Dispatch</span>
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
      )}

      {/* TAB 3: RAW MATERIALS */}
      {activeTab === 'raw_materials' && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-3">Raw Material</th>
                  <th className="pb-3">SKU</th>
                  <th className="pb-3">Current Stock</th>
                  <th className="pb-3">Unit</th>
                  <th className="pb-3">Reorder Threshold</th>
                  <th className="pb-3">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {rawMaterials.length === 0 ? (
                  <tr>
                    <td colSpan="6" className="py-12 text-center text-slate-400">
                      No raw materials recorded in ERP database.
                    </td>
                  </tr>
                ) : (
                  rawMaterials.map((rm) => {
                    const isLow = (rm.current_stock || 0) <= (rm.minimum_stock_level || 500);

                    return (
                      <tr key={rm.id} className="hover:bg-slate-50/80 transition-colors">
                        <td className="py-3.5 font-bold text-slate-900">{rm.name}</td>
                        <td className="py-3.5 font-mono text-slate-500">{rm.sku || '—'}</td>
                        <td className="py-3.5 font-bold text-slate-900">{rm.current_stock || 0}</td>
                        <td className="py-3.5 text-slate-600">{rm.unit_of_measure || 'units'}</td>
                        <td className="py-3.5 text-slate-600">{rm.minimum_stock_level || 500}</td>
                        <td className="py-3.5">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                            isLow
                              ? 'bg-rose-50 text-rose-700 border border-rose-200'
                              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          }`}>
                            {isLow ? 'REORDER REQUIRED' : 'SUFFICIENT'}
                          </span>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* RECORD PRODUCTION BATCH MODAL */}
      {isBatchModalOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsBatchModalOpen(false)}
          title="Record Plant Bottling Intake"
          maxWidth="max-w-md"
        >
          <form onSubmit={handleCreateBatch} className="space-y-4 text-xs">
            {batchError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-800 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{batchError}</span>
              </div>
            )}

            <div>
              <label className="block font-semibold text-slate-700">Batch Code / Tracking ID</label>
              <input
                type="text"
                required
                value={batchNumber}
                onChange={(e) => setBatchNumber(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-mono"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Finished Product SKU</label>
              <select
                value={batchProductId}
                onChange={(e) => setBatchProductId(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              >
                {products.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name} ({p.sku})
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Units Manufactured</label>
              <input
                type="number"
                min="1"
                required
                value={batchQuantity}
                onChange={(e) => setBatchQuantity(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Shelf Life (Days to Expiry)</label>
              <input
                type="number"
                min="30"
                required
                value={batchExpiryDays}
                onChange={(e) => setBatchExpiryDays(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsBatchModalOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmittingBatch}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSubmittingBatch ? 'Logging...' : 'Confirm Production Intake'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* DISPATCH STOCK REQUEST MODAL */}
      {selectedRequest && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedRequest(null)}
          title={`Dispatch Request #${selectedRequest.id}`}
          maxWidth="max-w-md"
        >
          <div className="space-y-4 text-xs">
            <div className="rounded-xl bg-slate-50 p-4 border border-slate-100 space-y-1">
              <p className="text-slate-500">
                Dealer: <span className="font-bold text-slate-900">{selectedRequest.dealer_name}</span>
              </p>
              <p className="text-slate-500">
                Product: <span className="font-bold text-slate-900">{selectedRequest.product_name}</span>
              </p>
              <p className="text-slate-500">
                Requested Quantity: <span className="font-bold text-sky-700">{selectedRequest.quantity_requested || selectedRequest.quantity} units</span>
              </p>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Dispatch / Loading Notes</label>
              <textarea
                rows="2"
                value={dispatchNotes}
                onChange={(e) => setDispatchNotes(e.target.value)}
                placeholder="Vehicle number, driver contact or dispatch notes..."
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setSelectedRequest(null)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={isDispatching}
                onClick={handleDispatchStockRequest}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isDispatching ? 'Dispatching...' : 'Confirm Dispatch'}
              </button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
