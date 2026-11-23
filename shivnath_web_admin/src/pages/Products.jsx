import React, { useState, useEffect } from 'react';
import { Package, Search, Plus, RefreshCw, AlertTriangle, Layers, Edit } from 'lucide-react';
import apiClient from '../api/client';
import Modal from '../components/common/Modal';
import { useAuth } from '../context/AuthContext';

export default function Products() {
  const { hasPermission } = useAuth();
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [adjustQty, setAdjustQty] = useState('');
  const [adjustReason, setAdjustReason] = useState('Stock Count Correction');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const fetchProducts = async () => {
    try {
      setIsLoading(true);
      const res = await apiClient.get('/api/products/');
      setProducts(res.data?.products || res.data?.results || (Array.isArray(res.data) ? res.data : []));
    } catch (err) {
      console.warn('Products fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchProducts();
  }, []);

  const handleAdjustInventory = async (e) => {
    e.preventDefault();
    if (!selectedProduct || !adjustQty) return;
    setIsSubmitting(true);

    try {
      await apiClient.post('/api/inventory/stock/adjust/', {
        entity_type: 'PRODUCT',
        entity_id: selectedProduct.id,
        adjusted_quantity: parseInt(adjustQty, 10),
        reason: adjustReason,
      });
      setSelectedProduct(null);
      setAdjustQty('');
      fetchProducts();
    } catch (err) {
      alert(err.response?.data?.error || err.message || 'Inventory adjustment failed');
    } finally {
      setIsSubmitting(false);
    }
  };

  const filtered = products.filter((p) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return p.name?.toLowerCase().includes(q) || p.sku?.toLowerCase().includes(q);
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Master Product Catalog</h1>
          <p className="text-sm text-slate-500">Packaged water SKUs, unit pricing, carton pack sizes & inventory</p>
        </div>

        <button
          onClick={fetchProducts}
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
            placeholder="Search product by name or SKU..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>
      </div>

      {/* Products Table */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Product Name</th>
                <th className="pb-3">SKU / Code</th>
                <th className="pb-3">Retail Price</th>
                <th className="pb-3">Dealer Price</th>
                <th className="pb-3">Pack Size</th>
                <th className="pb-3">Current Stock</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="7" className="py-12 text-center text-slate-400">
                    No products found.
                  </td>
                </tr>
              ) : (
                filtered.map((p) => {
                  const stock = p.current_stock ?? p.stock_quantity ?? 0;
                  const isLow = stock <= (p.reorder_level || 10);
                  return (
                    <tr key={p.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold text-slate-900 flex items-center space-x-2">
                        <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-sky-50 text-sky-600">
                          <Package className="h-4 w-4" />
                        </div>
                        <span>{p.name}</span>
                      </td>
                      <td className="py-3.5 font-mono text-slate-500">{p.sku || `SKU-${p.id}`}</td>
                      <td className="py-3.5 font-bold text-slate-900">₹{parseFloat(p.price || 0).toFixed(2)}</td>
                      <td className="py-3.5 font-semibold text-emerald-600">
                        ₹{parseFloat(p.wholesale_price || p.franchise_price || p.price || 0).toFixed(2)}
                      </td>
                      <td className="py-3.5 text-slate-600">{p.carton_pack_size || p.units_per_carton || 1} units / carton</td>
                      <td className="py-3.5">
                        <span className={`inline-flex items-center space-x-1 font-bold ${isLow ? 'text-rose-600' : 'text-slate-900'}`}>
                          {isLow && <AlertTriangle className="h-3.5 w-3.5 text-rose-500" />}
                          <span>{stock} units</span>
                        </span>
                      </td>
                      <td className="py-3.5 text-right">
                        {hasPermission('inventory', 'edit') && (
                          <button
                            onClick={() => setSelectedProduct(p)}
                            className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                          >
                            <Edit className="h-3.5 w-3.5" />
                            <span>Adjust Stock</span>
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

      {/* Adjust Inventory Modal */}
      {selectedProduct && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedProduct(null)}
          title={`Adjust Inventory — ${selectedProduct.name}`}
        >
          <form onSubmit={handleAdjustInventory} className="space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-slate-700">Quantity Change (+ to add, - to deduct)</label>
              <input
                type="number"
                required
                value={adjustQty}
                onChange={(e) => setAdjustQty(e.target.value)}
                placeholder="e.g. +50 or -10"
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Audit Reason</label>
              <select
                value={adjustReason}
                onChange={(e) => setAdjustReason(e.target.value)}
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              >
                <option value="Production Intake">Production Intake</option>
                <option value="Stock Count Correction">Stock Count Correction</option>
                <option value="Damaged / Leaked Disposal">Damaged / Leaked Disposal</option>
                <option value="Sample / Quality Testing">Sample / Quality Testing</option>
              </select>
            </div>

            <div className="flex justify-end space-x-2 pt-2">
              <button
                type="button"
                onClick={() => setSelectedProduct(null)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSubmitting ? 'Recording...' : 'Commit Adjustment'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
