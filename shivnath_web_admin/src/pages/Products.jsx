import React, { useState, useEffect } from 'react';
import { Package, Search, Plus, RefreshCw, AlertTriangle, Layers, Edit, CheckCircle2, Sliders } from 'lucide-react';
import apiClient from '../api/client';
import Modal from '../components/common/Modal';
import { useAuth } from '../context/AuthContext';

export default function Products() {
  const { hasPermission } = useAuth();
  const [products, setProducts] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');

  // Stock Adjustment State
  const [selectedProduct, setSelectedProduct] = useState(null);
  const [adjustQty, setAdjustQty] = useState('');
  const [adjustReason, setAdjustReason] = useState('Stock Count Correction');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Edit Product Pricing & Packaging State
  const [editingProduct, setEditingProduct] = useState(null);
  const [editPrice, setEditPrice] = useState('');
  const [editDealerPrice, setEditDealerPrice] = useState('');
  const [editMrp, setEditMrp] = useState('');
  const [editUnitsPerCase, setEditUnitsPerCase] = useState('');
  const [editGst, setEditGst] = useState('18');
  const [editStatus, setEditStatus] = useState('Active');
  const [editImageFile, setEditImageFile] = useState(null);
  const [editImagePreview, setEditImagePreview] = useState('');
  const [isSavingProduct, setIsSavingProduct] = useState(false);
  const [productSuccess, setProductSuccess] = useState('');

  // Add Product State
  const [isAddingProduct, setIsAddingProduct] = useState(false);
  const [newProductName, setNewProductName] = useState('');
  const [newProductSku, setNewProductSku] = useState('');
  const [newProductCategory, setNewProductCategory] = useState('Water Bottles');
  const [newProductSize, setNewProductSize] = useState('500 ML');
  const [newProductRetailPrice, setNewProductRetailPrice] = useState('');
  const [newProductDealerPrice, setNewProductDealerPrice] = useState('');
  const [newProductMrp, setNewProductMrp] = useState('');
  const [newProductUnitsPerCase, setNewProductUnitsPerCase] = useState('24');
  const [newProductGst, setNewProductGst] = useState('18');
  const [newProductImageFile, setNewProductImageFile] = useState(null);
  const [newProductImagePreview, setNewProductImagePreview] = useState('');
  const [isCreatingProduct, setIsCreatingProduct] = useState(false);

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

  const openEditModal = (p) => {
    setEditingProduct(p);
    setEditPrice(p.price || '');
    setEditDealerPrice(p.dealer_transfer_price || p.wholesale_price || p.price || '');
    setEditMrp(p.mrp || p.price || '');
    setEditUnitsPerCase(p.units_per_case || p.carton_pack_size || 24);
    setEditGst(p.gst ?? 18);
    setEditStatus(p.status || 'Active');
    setEditImageFile(null);
    setEditImagePreview(p.image || '');
    setProductSuccess('');
  };

  const handleSaveProductPricing = async (e) => {
    e.preventDefault();
    if (!editingProduct) return;
    setIsSavingProduct(true);
    setProductSuccess('');

    try {
      // 1. Update Pricing endpoint
      await apiClient.patch(`/api/products/${editingProduct.id}/pricing/`, {
        price: parseFloat(editPrice),
        dealer_transfer_price: parseFloat(editDealerPrice),
        mrp: parseFloat(editMrp),
        units_per_case: parseInt(editUnitsPerCase, 10),
        gst: parseInt(editGst, 10),
      });

      // 2. Also patch product status or image if changed
      if (editStatus !== editingProduct.status || editImageFile) {
        const prodData = new FormData();
        prodData.append('status', editStatus);
        if (editImageFile) {
          prodData.append('image', editImageFile);
        }
        await apiClient.patch(`/api/products/${editingProduct.id}/`, prodData, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
      }

      setProductSuccess('Product pricing and configuration updated successfully.');
      fetchProducts();
      setTimeout(() => {
        setEditingProduct(null);
        setProductSuccess('');
      }, 900);
    } catch (err) {
      alert(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to update product');
    } finally {
      setIsSavingProduct(false);
    }
  };

  const handleCreateProduct = async (e) => {
    e.preventDefault();
    setIsCreatingProduct(true);

    try {
      const formData = new FormData();
      formData.append('name', newProductName.trim());
      formData.append('sku', newProductSku.trim().toUpperCase());
      formData.append('category', newProductCategory);
      formData.append('size', newProductSize);
      formData.append('price', parseFloat(newProductRetailPrice));
      formData.append('dealer_transfer_price', parseFloat(newProductDealerPrice));
      formData.append('mrp', parseFloat(newProductMrp || newProductRetailPrice));
      formData.append('units_per_case', parseInt(newProductUnitsPerCase, 10));
      formData.append('gst', parseInt(newProductGst, 10));
      formData.append('status', 'Active');
      if (newProductImageFile) {
        formData.append('image', newProductImageFile);
      }

      await apiClient.post('/api/products/', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });

      setIsAddingProduct(false);
      setNewProductName('');
      setNewProductSku('');
      setNewProductRetailPrice('');
      setNewProductDealerPrice('');
      setNewProductMrp('');
      setNewProductImageFile(null);
      setNewProductImagePreview('');
      fetchProducts();
    } catch (err) {
      alert(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to create product');
    } finally {
      setIsCreatingProduct(false);
    }
  };

  const handleAdjustInventory = async (e) => {
    e.preventDefault();
    if (!selectedProduct || !adjustQty) return;
    setIsSubmitting(true);

    try {
      await apiClient.post('/api/inventory/stock/adjust/', {
        entity_type: 'PRODUCT',
        entity_id: selectedProduct.id,
        adjusted_quantity: parseInt(adjustQty, 10),
        reason: adjustReason?.trim() || 'Manual Finished Goods Stock Correction',
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

        <div className="flex items-center space-x-2">
          {hasPermission('products', 'create') && (
            <button
              onClick={() => setIsAddingProduct(true)}
              className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
            >
              <Plus className="h-4 w-4" />
              <span>Add Product</span>
            </button>
          )}

          <button
            onClick={fetchProducts}
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
                <th className="pb-3">Status</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="8" className="py-12 text-center text-slate-400">
                    No products found.
                  </td>
                </tr>
              ) : (
                filtered.map((p) => {
                  const stock = p.stock ?? p.current_stock ?? p.stock_quantity ?? 0;
                  const dealerPrice = p.dealer_transfer_price ?? p.wholesale_price ?? p.franchise_price ?? p.price ?? 0;
                  const packSize = p.units_per_case ?? p.carton_pack_size ?? p.units_per_carton ?? 1;
                  const isLow = stock <= (p.reorder_level || 10);
                  const isActive = (p.status || 'Active').toLowerCase() === 'active';

                  const resolveProductImg = (prod) => {
                    if (prod.image) {
                      const img = prod.image;
                      if (img.startsWith('http://') || img.startsWith('https://')) return img;
                      if (img.includes('200')) return '/products/bhoomi_200ml.png';
                      if (img.includes('250')) return '/products/bhoomi_250ml.png';
                      if (img.includes('500')) return '/products/bhoomi_500ml.png';
                      if (img.includes('1l') || img.includes('1000')) return '/products/bhoomi_1l.png';
                      return `${API_BASE_URL}/${img.replace(/^\//, '')}`;
                    }
                    const n = (prod.name || '').toLowerCase();
                    const s = (prod.sku || '').toLowerCase();
                    if (n.includes('200') || s.includes('200')) return '/products/bhoomi_200ml.png';
                    if (n.includes('250') || s.includes('250')) return '/products/bhoomi_250ml.png';
                    if (n.includes('500') || s.includes('500')) return '/products/bhoomi_500ml.png';
                    if (n.includes('1 litre') || n.includes('1l') || s.includes('1l')) return '/products/bhoomi_1l.png';
                    return null;
                  };

                  const productImg = resolveProductImg(p);

                  return (
                    <tr key={p.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold text-slate-900 flex items-center space-x-2.5">
                        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-sky-50 text-sky-600 shrink-0 overflow-hidden border border-slate-100 p-0.5">
                          {productImg ? (
                            <img src={productImg} alt={p.name} className="h-full w-full object-contain" />
                          ) : (
                            <Package className="h-4 w-4" />
                          )}
                        </div>
                        <div>
                          <div>{p.name}</div>
                          {p.category && <span className="text-[10px] text-slate-400 font-normal">{p.category}</span>}
                        </div>
                      </td>
                      <td className="py-3.5 font-mono text-slate-500 font-semibold">{p.sku || `SKU-${p.id}`}</td>
                      <td className="py-3.5 font-bold text-slate-900">₹{parseFloat(p.price || 0).toFixed(2)}</td>
                      <td className="py-3.5 font-bold text-emerald-600">
                        ₹{parseFloat(dealerPrice).toFixed(2)}
                      </td>
                      <td className="py-3.5 text-slate-600">{packSize} units / carton</td>
                      <td className="py-3.5">
                        <span className={`inline-flex items-center space-x-1 font-bold ${isLow ? 'text-rose-600' : 'text-slate-900'}`}>
                          {isLow && <AlertTriangle className="h-3.5 w-3.5 text-rose-500" />}
                          <span>{stock} units</span>
                        </span>
                      </td>
                      <td className="py-3.5">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                          isActive ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-slate-100 text-slate-600'
                        }`}>
                          {p.status || 'Active'}
                        </span>
                      </td>
                      <td className="py-3.5 text-right space-x-1.5 whitespace-nowrap">
                        <button
                          onClick={() => openEditModal(p)}
                          className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                          title="Edit Pricing & Carton Configuration"
                        >
                          <Sliders className="h-3.5 w-3.5 text-slate-500" />
                          <span>Pricing</span>
                        </button>

                        {hasPermission('inventory', 'edit') && (
                          <button
                            onClick={() => setSelectedProduct(p)}
                            className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2 py-1 text-xs font-semibold text-sky-700 hover:bg-sky-100"
                            title="Adjust Live Inventory Stock"
                          >
                            <Edit className="h-3.5 w-3.5 text-sky-600" />
                            <span>Stock</span>
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

      {/* Edit Pricing & Pack Size Modal */}
      {editingProduct && (
        <Modal
          isOpen={true}
          onClose={() => setEditingProduct(null)}
          title={`Edit Product — ${editingProduct.name}`}
          maxWidth="max-w-lg"
        >
          <form onSubmit={handleSaveProductPricing} className="space-y-4 text-xs">
            {productSuccess && (
              <div className="flex items-center space-x-2 rounded-lg bg-emerald-50 p-2.5 text-emerald-800 border border-emerald-200">
                <CheckCircle2 className="h-4 w-4 shrink-0" />
                <span>{productSuccess}</span>
              </div>
            )}

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block font-semibold text-slate-700">Retail Price (₹)</label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={editPrice}
                  onChange={(e) => setEditPrice(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Dealer Transfer Price (₹)</label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={editDealerPrice}
                  onChange={(e) => setEditDealerPrice(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Maximum Retail Price (MRP ₹)</label>
                <input
                  type="number"
                  step="0.01"
                  value={editMrp}
                  onChange={(e) => setEditMrp(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Units Per Carton / Case</label>
                <input
                  type="number"
                  min="1"
                  required
                  value={editUnitsPerCase}
                  onChange={(e) => setEditUnitsPerCase(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">GST Rate (%)</label>
                <select
                  value={editGst}
                  onChange={(e) => setEditGst(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="0">0% (Nil)</option>
                  <option value="5">5%</option>
                  <option value="12">12%</option>
                  <option value="18">18% (Standard Water)</option>
                  <option value="28">28%</option>
                </select>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Catalog Status</label>
                <select
                  value={editStatus}
                  onChange={(e) => setEditStatus(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="Active">Active</option>
                  <option value="Inactive">Inactive</option>
                </select>
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Product Image (Optional)</label>
                <div className="mt-1 flex items-center space-x-3">
                  {editImagePreview ? (
                    <img
                      src={editImagePreview}
                      alt="Product Preview"
                      className="h-14 w-14 object-contain rounded-lg border border-slate-200 bg-white p-1"
                    />
                  ) : (
                    <div className="h-14 w-14 rounded-lg border border-dashed border-slate-300 flex items-center justify-center text-slate-400">
                      <Package className="h-6 w-6" />
                    </div>
                  )}
                  <div className="flex-1">
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(e) => {
                        const file = e.target.files?.[0];
                        if (file) {
                          setEditImageFile(file);
                          setEditImagePreview(URL.createObjectURL(file));
                        }
                      }}
                      className="text-xs text-slate-600 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-semibold file:bg-sky-50 file:text-sky-700 hover:file:bg-sky-100"
                    />
                    <p className="text-[10px] text-slate-400 mt-1">Upload high-resolution bottle / jar artwork</p>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex justify-end space-x-2 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setEditingProduct(null)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSavingProduct}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSavingProduct ? 'Saving...' : 'Save Changes'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* Add New Product Modal */}
      {isAddingProduct && (
        <Modal
          isOpen={true}
          onClose={() => setIsAddingProduct(false)}
          title="Add New Catalog Product SKU"
          maxWidth="max-w-lg"
        >
          <form onSubmit={handleCreateProduct} className="space-y-4 text-xs">
            <div className="grid grid-cols-2 gap-4">
              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Product Name</label>
                <input
                  type="text"
                  required
                  value={newProductName}
                  onChange={(e) => setNewProductName(e.target.value)}
                  placeholder="e.g. Shivnath 500ml Travel Bottle"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">SKU Code</label>
                <input
                  type="text"
                  required
                  value={newProductSku}
                  onChange={(e) => setNewProductSku(e.target.value)}
                  placeholder="e.g. SHV-500"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none uppercase"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Category</label>
                <select
                  value={newProductCategory}
                  onChange={(e) => setNewProductCategory(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="Water Bottles">Water Bottles</option>
                  <option value="Water Jars">Water Jars</option>
                  <option value="Bulk Dispensers">Bulk Dispensers</option>
                </select>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Volume / Size</label>
                <input
                  type="text"
                  required
                  value={newProductSize}
                  onChange={(e) => setNewProductSize(e.target.value)}
                  placeholder="e.g. 500 ML or 20 Litre Jar"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Units Per Carton</label>
                <input
                  type="number"
                  min="1"
                  required
                  value={newProductUnitsPerCase}
                  onChange={(e) => setNewProductUnitsPerCase(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Retail Unit Price (₹)</label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={newProductRetailPrice}
                  onChange={(e) => setNewProductRetailPrice(e.target.value)}
                  placeholder="e.g. 10.00"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Dealer Transfer Price (₹)</label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={newProductDealerPrice}
                  onChange={(e) => setNewProductDealerPrice(e.target.value)}
                  placeholder="e.g. 7.00"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">MRP (₹)</label>
                <input
                  type="number"
                  step="0.01"
                  value={newProductMrp}
                  onChange={(e) => setNewProductMrp(e.target.value)}
                  placeholder="e.g. 10.00"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">GST Rate (%)</label>
                <select
                  value={newProductGst}
                  onChange={(e) => setNewProductGst(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="0">0%</option>
                  <option value="5">5%</option>
                  <option value="12">12%</option>
                  <option value="18">18%</option>
                </select>
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Product Image (Optional)</label>
                <div className="mt-1 flex items-center space-x-3">
                  {newProductImagePreview ? (
                    <img
                      src={newProductImagePreview}
                      alt="Product Preview"
                      className="h-14 w-14 object-contain rounded-lg border border-slate-200 bg-white p-1"
                    />
                  ) : (
                    <div className="h-14 w-14 rounded-lg border border-dashed border-slate-300 flex items-center justify-center text-slate-400">
                      <Package className="h-6 w-6" />
                    </div>
                  )}
                  <div className="flex-1">
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(e) => {
                        const file = e.target.files?.[0];
                        if (file) {
                          setNewProductImageFile(file);
                          setNewProductImagePreview(URL.createObjectURL(file));
                        }
                      }}
                      className="text-xs text-slate-600 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-semibold file:bg-sky-50 file:text-sky-700 hover:file:bg-sky-100"
                    />
                    <p className="text-[10px] text-slate-400 mt-1">Upload high-resolution bottle / jar artwork</p>
                  </div>
                </div>
              </div>
            </div>

            <div className="flex justify-end space-x-2 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsAddingProduct(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isCreatingProduct}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isCreatingProduct ? 'Creating...' : 'Create Product SKU'}
              </button>
            </div>
          </form>
        </Modal>
      )}

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
