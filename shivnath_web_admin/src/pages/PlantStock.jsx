import React, { useState, useEffect } from 'react';
import { 
  Factory, Package, Layers, Plus, RefreshCw, CheckCircle2, 
  AlertCircle, Clock, Truck, Check, DollarSign, ArrowUpRight, 
  Warehouse, Calendar, ShieldCheck, Sliders 
} from 'lucide-react';
import apiClient from '../api/client';
import Modal from '../components/common/Modal';
import { useAuth } from '../context/AuthContext';

export default function PlantStock() {
  const { hasPermission } = useAuth();
  const [activeTab, setActiveTab] = useState('batches'); // 'batches' | 'requests' | 'raw_materials' | 'central_stock'

  // Data States
  const [batches, setBatches] = useState([]);
  const [stockRequests, setStockRequests] = useState([]);
  const [rawMaterials, setRawMaterials] = useState([]);
  const [products, setProducts] = useState([]);
  const [inventoryItems, setInventoryItems] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  // New Batch Modal State
  const [isBatchModalOpen, setIsBatchModalOpen] = useState(false);
  const [batchNumber, setBatchNumber] = useState('');
  const [batchProductId, setBatchProductId] = useState('');
  const [batchQuantity, setBatchQuantity] = useState(500);
  const [batchExpiryDays, setBatchExpiryDays] = useState(180);
  const [isSubmittingBatch, setIsSubmittingBatch] = useState(false);
  const [batchError, setBatchError] = useState('');

  // Batch Collection / Dispatch Modal State
  const [selectedBatchForCollection, setSelectedBatchForCollection] = useState(null);
  const [collectionQty, setCollectionQty] = useState('');
  const [collectionClient, setCollectionClient] = useState('');
  const [collectionNotes, setCollectionNotes] = useState('');
  const [collectionPayStatus, setCollectionPayStatus] = useState('PAID');
  const [collectionPayMethod, setCollectionPayMethod] = useState('CASH');
  const [isCollecting, setIsCollecting] = useState(false);
  const [collectionError, setCollectionError] = useState('');

  // Stock Request Dispatch State
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [dispatchNotes, setDispatchNotes] = useState('');
  const [isDispatching, setIsDispatching] = useState(false);
  const [dispatchError, setDispatchError] = useState('');

  // Product Stock Adjustment State
  const [selectedAdjustProduct, setSelectedAdjustProduct] = useState(null);
  const [adjustStockQty, setAdjustStockQty] = useState('');
  const [adjustStockReason, setAdjustStockReason] = useState('Manual Stock Audit Correction');
  const [isSubmittingAdjust, setIsSubmittingAdjust] = useState(false);
  const [adjustStockError, setAdjustStockError] = useState('');

  // New Raw Material Modal State
  const [isRawModalOpen, setIsRawModalOpen] = useState(false);
  const [rawName, setRawName] = useState('');
  const [rawCategory, setRawCategory] = useState('PET_PREFORMS');
  const [rawSku, setRawSku] = useState('');
  const [rawQuantity, setRawQuantity] = useState(1000);
  const [rawUnit, setRawUnit] = useState('pcs');
  const [rawMinLevel, setRawMinLevel] = useState(500);
  const [rawCost, setRawCost] = useState('1.50');
  const [isSubmittingRaw, setIsSubmittingRaw] = useState(false);
  const [rawError, setRawError] = useState('');

  const fetchPlantData = async () => {
    try {
      setIsLoading(true);
      const [batchesRes, reqRes, rawRes, prodsRes, itemsRes] = await Promise.all([
        apiClient.get('/api/inventory/production-batches/').catch(() => ({ data: [] })),
        apiClient.get('/api/inventory/dealer-stock-requests/').catch(() => ({ data: [] })),
        apiClient.get('/api/inventory/raw-materials/').catch(() => ({ data: [] })),
        apiClient.get('/api/products/').catch(() => ({ data: [] })),
        apiClient.get('/api/inventory/items/').catch(() => ({ data: [] })),
      ]);

      setBatches(batchesRes.data?.batches || batchesRes.data?.results || (Array.isArray(batchesRes.data) ? batchesRes.data : []));
      setStockRequests(reqRes.data?.requests || reqRes.data?.results || (Array.isArray(reqRes.data) ? reqRes.data : []));
      setRawMaterials(rawRes.data?.raw_materials || rawRes.data?.results || (Array.isArray(rawRes.data) ? rawRes.data : []));
      
      const pList = prodsRes.data?.products || prodsRes.data?.results || (Array.isArray(prodsRes.data) ? prodsRes.data : []);
      setProducts(pList);
      if (pList.length > 0 && !batchProductId) {
        setBatchProductId(pList[0].id.toString());
      }

      setInventoryItems(itemsRes.data?.results || itemsRes.data?.items || (Array.isArray(itemsRes.data) ? itemsRes.data : []));
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
    if (!batchProductId && products.length > 0) {
      setBatchProductId(products[0].id.toString());
    }
    setBatchError('');
    setIsBatchModalOpen(true);
  };

  const handleCreateBatch = async (e) => {
    e.preventDefault();
    setIsSubmittingBatch(true);
    setBatchError('');

    const resolvedProductId = batchProductId || (products.length > 0 ? products[0].id.toString() : '');
    if (!resolvedProductId) {
      setBatchError('Please select a finished product SKU.');
      setIsSubmittingBatch(false);
      return;
    }

    try {
      const expDate = new Date();
      expDate.setDate(expDate.getDate() + parseInt(batchExpiryDays, 10));

      await apiClient.post('/api/inventory/production-batches/', {
        batch_number: batchNumber.trim(),
        product: parseInt(resolvedProductId, 10),
        product_id: parseInt(resolvedProductId, 10),
        quantity_produced_units: parseInt(batchQuantity, 10),
        quantity_manufactured: parseInt(batchQuantity, 10),
        quantity: parseInt(batchQuantity, 10),
        shelf_life_days: parseInt(batchExpiryDays, 10) || 180,
        expiry_date: expDate.toISOString().slice(0, 10),
      });

      setIsBatchModalOpen(false);
      fetchPlantData();
    } catch (err) {
      setBatchError(err.response?.data?.error || err.response?.data?.message || err.message || 'Failed to record batch');
    } finally {
      setIsSubmittingBatch(false);
    }
  };

  const handleRecordCollection = async (e) => {
    e.preventDefault();
    if (!selectedBatchForCollection || !collectionQty) return;
    setIsCollecting(true);
    setCollectionError('');

    try {
      await apiClient.post(`/api/inventory/production-batches/${selectedBatchForCollection.id}/collection/`, {
        quantity_collected: parseInt(collectionQty, 10),
        client_name: collectionClient.trim() || 'Central Plant Client / Dealer',
        notes: collectionNotes.trim(),
        payment_status: collectionPayStatus,
        payment_method: collectionPayMethod,
      });

      setSelectedBatchForCollection(null);
      setCollectionQty('');
      setCollectionClient('');
      setCollectionNotes('');
      fetchPlantData();
    } catch (err) {
      setCollectionError(err.response?.data?.error || err.response?.data?.message || err.message || 'Failed to record collection');
    } finally {
      setIsCollecting(false);
    }
  };

  const handleDispatchStockRequest = async () => {
    if (!selectedRequest) return;
    setIsDispatching(true);
    setDispatchError('');

    try {
      await apiClient.post(`/api/inventory/dealer-stock-requests/${selectedRequest.id}/dispatch/`, {
        notes: dispatchNotes || 'Stock dispatched from Central Bottling Plant',
      });
      setSelectedRequest(null);
      setDispatchNotes('');
      fetchPlantData();
    } catch (err) {
      const msg = err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to dispatch request';
      setDispatchError(msg);
    } finally {
      setIsDispatching(false);
    }
  };

  const handleCreateRawMaterial = async (e) => {
    e.preventDefault();
    setIsSubmittingRaw(true);
    setRawError('');

    try {
      await apiClient.post('/api/inventory/raw-materials/', {
        name: rawName.trim(),
        category: rawCategory,
        sku: rawSku.trim() || `${rawCategory.slice(0, 3)}-${Date.now().toString().slice(-4)}`,
        current_stock: parseFloat(rawQuantity || 0),
        unit_of_measure: rawUnit,
        minimum_stock_level: parseFloat(rawMinLevel || 0),
        unit_cost: parseFloat(rawCost || 0),
      });

      setIsRawModalOpen(false);
      setRawName('');
      setRawSku('');
      setRawQuantity(1000);
      fetchPlantData();
    } catch (err) {
      const msg = err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to record raw material';
      setRawError(msg);
    } finally {
      setIsSubmittingRaw(false);
    }
  };

  const handleAdjustProductStock = async (e) => {
    e.preventDefault();
    if (!selectedAdjustProduct || !adjustStockQty) return;
    setIsSubmittingAdjust(true);
    setAdjustStockError('');

    try {
      await apiClient.post('/api/inventory/stock/adjust/', {
        entity_type: 'PRODUCT',
        entity_id: selectedAdjustProduct.id,
        adjusted_quantity: parseInt(adjustStockQty, 10),
        reason: adjustStockReason.trim() || 'Manual Finished Goods Correction',
      });
      setSelectedAdjustProduct(null);
      setAdjustStockQty('');
      fetchPlantData();
    } catch (err) {
      const msg = err.response?.data?.error || err.response?.data?.message || err.message || 'Stock adjustment failed.';
      setAdjustStockError(msg);
    } finally {
      setIsSubmittingAdjust(false);
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
      <div className="flex space-x-2 border-b border-slate-200 text-xs font-semibold overflow-x-auto pb-px">
        <button
          onClick={() => setActiveTab('batches')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 shrink-0 ${
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
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 shrink-0 ${
            activeTab === 'requests'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Truck className="h-4 w-4" />
          <span>Dealer Stock Requests ({stockRequests.filter(r => (r.status || '').toUpperCase() === 'PENDING').length} pending)</span>
        </button>

        <button
          onClick={() => setActiveTab('raw_materials')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 shrink-0 ${
            activeTab === 'raw_materials'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Layers className="h-4 w-4" />
          <span>Raw Materials Inventory ({rawMaterials.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('central_stock')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 shrink-0 ${
            activeTab === 'central_stock'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Warehouse className="h-4 w-4" />
          <span>Finished Goods Inventory ({inventoryItems.length})</span>
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
                  <th className="pb-3">Remaining Plant Stock</th>
                  <th className="pb-3">Mfg Date</th>
                  <th className="pb-3">Expiry Date</th>
                  <th className="pb-3">Linked Order</th>
                  <th className="pb-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {batches.length === 0 ? (
                  <tr>
                    <td colSpan="8" className="py-12 text-center text-slate-400">
                      No production batches recorded yet.
                    </td>
                  </tr>
                ) : (
                  batches.map((b) => {
                    const remaining = b.quantity_remaining_company ?? b.quantity_manufactured ?? 0;
                    const isExhausted = remaining <= 0;

                    return (
                      <tr key={b.id} className="hover:bg-slate-50/80 transition-colors">
                        <td className="py-3.5 font-mono font-bold text-sky-600">{b.batch_number}</td>
                        <td className="py-3.5 font-bold text-slate-900">{b.product_name || `Product #${b.product}`}</td>
                        <td className="py-3.5 text-slate-700">{b.quantity_manufactured} units</td>
                        <td className="py-3.5">
                          <span className={`font-bold ${isExhausted ? 'text-slate-400' : 'text-emerald-600'}`}>
                            {remaining} units
                          </span>
                        </td>
                        <td className="py-3.5 text-slate-500">
                          {b.manufacturing_date ? new Date(b.manufacturing_date).toLocaleDateString() : 'Today'}
                        </td>
                        <td className="py-3.5 text-slate-500">
                          {b.expiry_date ? new Date(b.expiry_date).toLocaleDateString() : '—'}
                        </td>
                        <td className="py-3.5 text-slate-600">
                          {b.linked_order ? (
                            <span className="font-semibold text-sky-700">Order #{b.linked_order}</span>
                          ) : (
                            <span className="text-slate-400">General Plant Stock</span>
                          )}
                        </td>
                        <td className="py-3.5 text-right">
                          {!isExhausted && hasPermission('inventory', 'edit') && (
                            <button
                              onClick={() => {
                                setSelectedBatchForCollection(b);
                                setCollectionQty(remaining.toString());
                                setCollectionError('');
                              }}
                              className="inline-flex items-center space-x-1 rounded-md bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-100 border border-emerald-200"
                            >
                              <ArrowUpRight className="h-3.5 w-3.5" />
                              <span>Dispatch / Collect</span>
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
                    const statusStr = (req.status || 'PENDING').toUpperCase();
                    const isPending = statusStr === 'PENDING';

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
                              : statusStr === 'DISPATCHED'
                              ? 'bg-purple-50 text-purple-700 border border-purple-200'
                              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          }`}>
                            {statusStr}
                          </span>
                        </td>
                        <td className="py-3.5 text-slate-500">
                          {req.created_at ? new Date(req.created_at).toLocaleDateString() : 'Today'}
                        </td>
                        <td className="py-3.5 text-right">
                          {isPending && hasPermission('inventory', 'edit') && (
                            <button
                              onClick={() => {
                                setSelectedRequest(req);
                                setDispatchError('');
                              }}
                              className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2.5 py-1 text-xs font-semibold text-sky-700 hover:bg-sky-100 border border-sky-200"
                            >
                              <Truck className="h-3.5 w-3.5" />
                              <span>Fulfill & Dispatch</span>
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

      {/* TAB 3: RAW MATERIALS INVENTORY */}
      {activeTab === 'raw_materials' && (
        <div className="space-y-4">
          <div className="flex justify-end">
            {hasPermission('inventory', 'edit') && (
              <button
                onClick={() => {
                  setRawError('');
                  setIsRawModalOpen(true);
                }}
                className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-sky-500"
              >
                <Plus className="h-4 w-4" />
                <span>Add Raw Material / Stock Intake</span>
              </button>
            )}
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                  <tr>
                    <th className="pb-3">Raw Material</th>
                    <th className="pb-3">Category</th>
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
                      <td colSpan="7" className="py-12 text-center text-slate-400">
                        No raw materials recorded in ERP database.
                      </td>
                    </tr>
                  ) : (
                    rawMaterials.map((rm) => {
                      const isLow = (rm.current_stock || 0) <= (rm.minimum_stock_level || 500);

                      return (
                        <tr key={rm.id} className="hover:bg-slate-50/80 transition-colors">
                          <td className="py-3.5 font-bold text-slate-900">{rm.name}</td>
                          <td className="py-3.5 text-slate-600">{rm.category || 'General'}</td>
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
        </div>
      )}

      {/* TAB 4: FINISHED GOODS INVENTORY */}
      {activeTab === 'central_stock' && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-3">Product Item</th>
                  <th className="pb-3">SKU</th>
                  <th className="pb-3">Package / Size</th>
                  <th className="pb-3">Central Plant Physical Stock</th>
                  <th className="pb-3">Threshold Alert</th>
                  <th className="pb-3">Unit Price</th>
                  <th className="pb-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {products.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="py-12 text-center text-slate-400">
                      No products recorded in catalog.
                    </td>
                  </tr>
                ) : (
                  products.map((p) => {
                    const stock = p.stock ?? p.current_stock ?? 0;
                    const isLow = stock <= 50;

                    return (
                      <tr key={p.id} className="hover:bg-slate-50/80 transition-colors">
                        <td className="py-3.5 font-bold text-slate-900">{p.name}</td>
                        <td className="py-3.5 font-mono text-slate-600">{p.sku}</td>
                        <td className="py-3.5 text-slate-600">{p.size || p.unit || 'Packaged'}</td>
                        <td className="py-3.5">
                          <span className={`font-bold text-sm ${stock <= 0 ? 'text-rose-600 font-extrabold' : 'text-slate-900'}`}>
                            {stock} units
                          </span>
                        </td>
                        <td className="py-3.5">
                          <span className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                            stock <= 0
                              ? 'bg-rose-50 text-rose-700 border border-rose-200'
                              : isLow
                              ? 'bg-amber-50 text-amber-700 border border-amber-200'
                              : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                          }`}>
                            {stock <= 0 ? 'OUT OF STOCK' : isLow ? 'LOW STOCK' : 'IN STOCK'}
                          </span>
                        </td>
                        <td className="py-3.5 font-bold text-slate-900">₹{p.price || 0}</td>
                        <td className="py-3.5 text-right">
                          <button
                            onClick={() => {
                              setSelectedAdjustProduct(p);
                              setAdjustStockQty('');
                              setAdjustStockReason('Physical inventory audit correction');
                              setAdjustStockError('');
                            }}
                            className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2.5 py-1 text-[11px] font-semibold text-sky-700 hover:bg-sky-100 border border-sky-200 transition-colors"
                          >
                            <Sliders className="h-3.5 w-3.5" />
                            <span>Adjust Stock</span>
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
      )}

      {/* RECORD PRODUCTION BATCH MODAL */}
      {isBatchModalOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsBatchModalOpen(false)}
          title="Record Central Plant Bottling Intake"
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
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none bg-white"
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
          title={`Fulfill & Dispatch Stock Request #${selectedRequest.id}`}
          maxWidth="max-w-md"
        >
          <div className="space-y-4 text-xs">
            {dispatchError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-800 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{dispatchError}</span>
              </div>
            )}

            <div className="rounded-xl bg-slate-50 p-4 border border-slate-100 space-y-1">
              <p className="text-slate-500">
                Franchise Dealer: <span className="font-bold text-slate-900">{selectedRequest.dealer_name}</span>
              </p>
              <p className="text-slate-500">
                Product SKU: <span className="font-bold text-slate-900">{selectedRequest.product_name}</span>
              </p>
              <p className="text-slate-500">
                Requested Quantity: <span className="font-bold text-sky-700">{selectedRequest.quantity_requested || selectedRequest.quantity} units</span>
              </p>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Dispatch / Truck Loading Notes</label>
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
                {isDispatching ? 'Dispatching...' : 'Confirm Dispatch to Franchise'}
              </button>
            </div>
          </div>
        </Modal>
      )}

      {/* RECORD BATCH COLLECTION / DISPATCH MODAL */}
      {selectedBatchForCollection && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedBatchForCollection(null)}
          title={`Dispatch from Batch #${selectedBatchForCollection.batch_number}`}
          maxWidth="max-w-md"
        >
          <form onSubmit={handleRecordCollection} className="space-y-4 text-xs">
            {collectionError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-800 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{collectionError}</span>
              </div>
            )}

            <div className="bg-sky-50 rounded-xl p-3 border border-sky-100">
              <p className="text-sky-950 font-bold">{selectedBatchForCollection.product_name}</p>
              <p className="text-sky-700 text-[11px] mt-0.5">
                Available in batch: {selectedBatchForCollection.quantity_remaining_company ?? selectedBatchForCollection.quantity_manufactured} units
              </p>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Quantity to Dispatch / Collect</label>
              <input
                type="number"
                min="1"
                max={selectedBatchForCollection.quantity_remaining_company ?? selectedBatchForCollection.quantity_manufactured}
                required
                value={collectionQty}
                onChange={(e) => setCollectionQty(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-bold"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Receiving Client / Dealer Name</label>
              <input
                type="text"
                required
                value={collectionClient}
                onChange={(e) => setCollectionClient(e.target.value)}
                placeholder="e.g. Digital Marketing Wala, City Franchise Depot..."
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Payment Status</label>
              <select
                value={collectionPayStatus}
                onChange={(e) => setCollectionPayStatus(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none bg-white"
              >
                <option value="PAID">Paid / Cleared</option>
                <option value="UNPAID">Pending / On Credit</option>
                <option value="PARTIAL">Partially Paid</option>
              </select>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Payment Method</label>
              <select
                value={collectionPayMethod}
                onChange={(e) => setCollectionPayMethod(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none bg-white"
              >
                <option value="CASH">Cash</option>
                <option value="UPI">UPI</option>
                <option value="BANK_TRANSFER">Bank Transfer</option>
                <option value="CHEQUE">Cheque</option>
              </select>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Dispatch Notes</label>
              <input
                type="text"
                value={collectionNotes}
                onChange={(e) => setCollectionNotes(e.target.value)}
                placeholder="e.g. Gate pass #1042, truck load..."
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setSelectedBatchForCollection(null)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isCollecting}
                className="rounded-lg bg-emerald-600 px-4 py-2 font-semibold text-white hover:bg-emerald-500 disabled:opacity-50"
              >
                {isCollecting ? 'Recording...' : 'Confirm Dispatch'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* RECORD RAW MATERIAL MODAL */}
      {isRawModalOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsRawModalOpen(false)}
          title="Add Raw Material / Stock Intake"
          maxWidth="max-w-md"
        >
          <form onSubmit={handleCreateRawMaterial} className="space-y-4 text-xs">
            {rawError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-800 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{rawError}</span>
              </div>
            )}

            <div>
              <label className="block font-semibold text-slate-700">Material Name</label>
              <input
                type="text"
                required
                value={rawName}
                onChange={(e) => setRawName(e.target.value)}
                placeholder="e.g. 1L Pet Preforms, 28mm Caps, Shrink Film..."
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Category</label>
              <select
                value={rawCategory}
                onChange={(e) => setRawCategory(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none bg-white"
              >
                <option value="PET_PREFORMS">PET Preforms</option>
                <option value="CAPS">Bottle Caps / Jar Caps</option>
                <option value="LABELS">Packaging Labels</option>
                <option value="CORRUGATED_BOXES">Corrugated Carton Boxes</option>
                <option value="CHEMICALS">Water Treatment Minerals / Chemicals</option>
                <option value="PACKAGING">Secondary Packaging / Shrink Wrap</option>
                <option value="WATER">Source Raw Water</option>
              </select>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Intake Quantity</label>
                <input
                  type="number"
                  required
                  min="1"
                  value={rawQuantity}
                  onChange={(e) => setRawQuantity(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-bold"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Unit of Measure</label>
                <input
                  type="text"
                  required
                  value={rawUnit}
                  onChange={(e) => setRawUnit(e.target.value)}
                  placeholder="pcs, kg, boxes..."
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Reorder Minimum Threshold</label>
                <input
                  type="number"
                  required
                  value={rawMinLevel}
                  onChange={(e) => setRawMinLevel(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Unit Cost (₹)</label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={rawCost}
                  onChange={(e) => setRawCost(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsRawModalOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmittingRaw}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSubmittingRaw ? 'Saving...' : 'Add Material Intake'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* ADJUST PRODUCT STOCK MODAL */}
      {selectedAdjustProduct && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedAdjustProduct(null)}
          title={`Adjust Physical Stock: ${selectedAdjustProduct.name} (${selectedAdjustProduct.sku})`}
          maxWidth="max-w-md"
        >
          <form onSubmit={handleAdjustProductStock} className="space-y-4 text-xs">
            {adjustStockError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{adjustStockError}</span>
              </div>
            )}

            <div className="rounded-lg bg-slate-50 p-3 border border-slate-200">
              <p className="text-slate-500 font-medium">Current Recorded Stock:</p>
              <p className="text-lg font-bold text-slate-900 mt-0.5">
                {selectedAdjustProduct.stock ?? selectedAdjustProduct.current_stock ?? 0} units
              </p>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">
                Adjustment Quantity (Use positive to add, negative to deduct)
              </label>
              <input
                type="number"
                required
                placeholder="e.g. 100 or -50"
                value={adjustStockQty}
                onChange={(e) => setAdjustStockQty(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Audit Reason / Note</label>
              <textarea
                rows="2"
                required
                placeholder="Mandatory explanation for audit trail..."
                value={adjustStockReason}
                onChange={(e) => setAdjustStockReason(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setSelectedAdjustProduct(null)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmittingAdjust}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSubmittingAdjust ? 'Updating...' : 'Save Stock Adjustment'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
