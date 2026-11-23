import React, { useState, useEffect } from 'react';
import { Layers, MapPin, Truck, Check, RefreshCw, AlertCircle, Save } from 'lucide-react';
import apiClient from '../api/client';
import { useAuth } from '../context/AuthContext';

export default function MoqDelivery() {
  const { hasPermission } = useAuth();

  // 1. MOQ Policy A state
  const [moqRules, setMoqRules] = useState([]);
  const [products, setProducts] = useState([]);
  const [selectedProduct, setSelectedProduct] = useState('');
  const [adminMoq, setAdminMoq] = useState(1);
  const [allowFranchiseOverride, setAllowFranchiseOverride] = useState(true);
  const [maxFranchiseMoq, setMaxFranchiseMoq] = useState('');
  const [moqSuccess, setMoqSuccess] = useState('');

  // 2. Policy A Simulator state
  const [simProduct, setSimProduct] = useState('');
  const [simFranchiseMoq, setSimFranchiseMoq] = useState(1);
  const [simEffectiveMoq, setSimEffectiveMoq] = useState(1);

  // 3. Dispatch Origin Coordinates state
  const [origin, setOrigin] = useState({
    name: '',
    latitude: '',
    longitude: '',
    address: '',
  });
  const [originSuccess, setOriginSuccess] = useState('');

  // 4. Distance Slabs state
  const [bands, setBands] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  const fetchData = async () => {
    try {
      setIsLoading(true);
      const [rulesRes, prodsRes, originRes, bandsRes] = await Promise.all([
        apiClient.get('/api/products/packaging-rules/?baseline_only=true'),
        apiClient.get('/api/products/'),
        apiClient.get('/api/billing/delivery/origin/'),
        apiClient.get('/api/billing/delivery/bands/'),
      ]);

      setMoqRules(rulesRes.data?.rules || rulesRes.data?.results || []);
      setProducts(prodsRes.data?.products || prodsRes.data?.results || (Array.isArray(prodsRes.data) ? prodsRes.data : []));
      if (originRes.data?.origin) {
        setOrigin(originRes.data.origin);
      }
      setBands(bandsRes.data?.bands || bandsRes.data?.results || []);
    } catch (err) {
      console.warn('MOQ Delivery fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // Recalculate Policy A Simulator: Effective MOQ = max(Admin Baseline, Franchise MOQ)
  useEffect(() => {
    if (!simProduct) return;
    const rule = moqRules.find((r) => r.product_id === parseInt(simProduct, 10));
    const baseline = rule?.min_order_quantity || 1;
    const eff = Math.max(baseline, parseInt(simFranchiseMoq || 1, 10));
    setSimEffectiveMoq(eff);
  }, [simProduct, simFranchiseMoq, moqRules]);

  const handleSaveBaselineMoq = async (e) => {
    e.preventDefault();
    setMoqSuccess('');
    try {
      await apiClient.post('/api/products/packaging-rules/', {
        product_id: selectedProduct,
        min_order_quantity: parseInt(adminMoq, 10),
        allow_franchise_override: allowFranchiseOverride,
        max_franchise_moq: maxFranchiseMoq ? parseInt(maxFranchiseMoq, 10) : null,
        channel: 'CUSTOMER',
      });
      setMoqSuccess('Admin baseline MOQ policy updated successfully.');
      fetchData();
    } catch (err) {
      alert(err.response?.data?.message || err.message || 'Failed to update MOQ rule.');
    }
  };

  const handleSaveOrigin = async (e) => {
    e.preventDefault();
    setOriginSuccess('');
    try {
      await apiClient.post('/api/billing/delivery/origin/', origin);
      setOriginSuccess('Authoritative dispatch depot coordinates saved.');
      fetchData();
    } catch (err) {
      alert(err.response?.data?.message || err.message || 'Failed to update delivery origin.');
    }
  };

  return (
    <div className="space-y-8">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">MOQ Policy & Delivery Logistics</h1>
          <p className="text-sm text-slate-500">
            Authoritative Policy A minimum order packaging rules & distance-band delivery tariffs
          </p>
        </div>

        <button
          onClick={fetchData}
          className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
        >
          <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
          <span>Refresh</span>
        </button>
      </div>

      {/* Grid: Policy A Rules & Policy A Simulator */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Policy A Admin Baseline Form */}
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center space-x-2 mb-4">
            <Layers className="h-5 w-5 text-sky-600" />
            <h2 className="text-base font-bold text-slate-900">Policy A — Company Baseline Rules</h2>
          </div>
          <p className="text-xs text-slate-500 mb-4">
            Admin defines mandatory company floor MOQ. Franchise overrides cannot fall below this floor.
          </p>

          {moqSuccess && (
            <div className="mb-4 flex items-center space-x-2 rounded-lg bg-emerald-50 p-3 text-xs text-emerald-700 border border-emerald-200">
              <Check className="h-4 w-4" />
              <span>{moqSuccess}</span>
            </div>
          )}

          <form onSubmit={handleSaveBaselineMoq} className="space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-slate-700">Target Product</label>
              <select
                required
                value={selectedProduct}
                onChange={(e) => setSelectedProduct(e.target.value)}
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              >
                <option value="">Select SKU...</option>
                {products.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Admin Baseline MOQ</label>
                <input
                  type="number"
                  min="1"
                  required
                  value={adminMoq}
                  onChange={(e) => setAdminMoq(e.target.value)}
                  className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
              <div>
                <label className="block font-semibold text-slate-700">Max Franchise Ceiling (Optional)</label>
                <input
                  type="number"
                  min="1"
                  value={maxFranchiseMoq}
                  onChange={(e) => setMaxFranchiseMoq(e.target.value)}
                  placeholder="e.g. 50"
                  className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            <div className="flex items-center space-x-2 pt-1">
              <input
                type="checkbox"
                id="allowOverride"
                checked={allowFranchiseOverride}
                onChange={(e) => setAllowFranchiseOverride(e.target.checked)}
                className="h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500"
              />
              <label htmlFor="allowOverride" className="font-medium text-slate-700">
                Allow Franchise Dealers to configure higher custom MOQ overrides
              </label>
            </div>

            {hasPermission('moq', 'edit') && (
              <button
                type="submit"
                className="inline-flex items-center space-x-2 rounded-lg bg-sky-600 px-4 py-2 text-xs font-semibold text-white hover:bg-sky-500 shadow-sm"
              >
                <Save className="h-4 w-4" />
                <span>Save Baseline Rule</span>
              </button>
            )}
          </form>
        </div>

        {/* Policy A Live Rule Engine Simulator */}
        <div className="rounded-2xl border border-sky-200 bg-sky-50/50 p-6 shadow-sm">
          <div className="flex items-center space-x-2 mb-2">
            <Layers className="h-5 w-5 text-sky-700" />
            <h2 className="text-base font-bold text-sky-900">Policy A Live Decision Simulator</h2>
          </div>
          <p className="text-xs text-sky-700 mb-4 font-mono">
            Formula: Effective MOQ = max(Admin Baseline, Franchise MOQ)
          </p>

          <div className="space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-slate-700">Test Product</label>
              <select
                value={simProduct}
                onChange={(e) => setSimProduct(e.target.value)}
                className="mt-1.5 block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              >
                <option value="">Choose product to simulate...</option>
                {products.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Simulated Franchise Requested MOQ</label>
              <input
                type="number"
                min="1"
                value={simFranchiseMoq}
                onChange={(e) => setSimFranchiseMoq(e.target.value)}
                className="mt-1.5 block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            {simProduct && (
              <div className="rounded-xl border border-sky-200 bg-white p-4 space-y-2">
                <div className="flex justify-between">
                  <span className="text-slate-500">Admin Baseline Floor:</span>
                  <span className="font-bold text-slate-800">
                    {moqRules.find((r) => r.product_id === parseInt(simProduct, 10))?.min_order_quantity || 1} units
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Franchise Override Setting:</span>
                  <span className="font-bold text-slate-800">{simFranchiseMoq} units</span>
                </div>
                <div className="border-t border-slate-100 pt-2 flex justify-between items-center text-sm">
                  <span className="font-bold text-sky-900">Effective Checkout MOQ:</span>
                  <span className="rounded-lg bg-sky-600 px-3 py-1 font-bold text-white text-base">
                    {simEffectiveMoq} units
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Grid: Dispatch Origin & Distance Bands */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Dispatch Origin Settings Form */}
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center space-x-2 mb-4">
            <MapPin className="h-5 w-5 text-indigo-600" />
            <h2 className="text-base font-bold text-slate-900">Authoritative Dispatch Origin</h2>
          </div>
          <p className="text-xs text-slate-500 mb-4">
            Base depot coordinates used by the Haversine distance engine to calculate delivery fees
          </p>

          {originSuccess && (
            <div className="mb-4 flex items-center space-x-2 rounded-lg bg-emerald-50 p-3 text-xs text-emerald-700 border border-emerald-200">
              <Check className="h-4 w-4" />
              <span>{originSuccess}</span>
            </div>
          )}

          <form onSubmit={handleSaveOrigin} className="space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-slate-700">Depot / Agency Name</label>
              <input
                type="text"
                required
                value={origin.name || ''}
                onChange={(e) => setOrigin({ ...origin, name: e.target.value })}
                placeholder="Water Wala Central Bottling Plant"
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Latitude (e.g. 21.1904)</label>
                <input
                  type="text"
                  required
                  value={origin.latitude || ''}
                  onChange={(e) => setOrigin({ ...origin, latitude: e.target.value })}
                  placeholder="21.190448"
                  className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
              <div>
                <label className="block font-semibold text-slate-700">Longitude (e.g. 81.2849)</label>
                <input
                  type="text"
                  required
                  value={origin.longitude || ''}
                  onChange={(e) => setOrigin({ ...origin, longitude: e.target.value })}
                  placeholder="81.284920"
                  className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Depot Address</label>
              <textarea
                rows={2}
                value={origin.address || ''}
                onChange={(e) => setOrigin({ ...origin, address: e.target.value })}
                placeholder="Industrial Area, Durg / Bhilai, CG"
                className="mt-1.5 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            {hasPermission('billing', 'edit') && (
              <button
                type="submit"
                className="inline-flex items-center space-x-2 rounded-lg bg-indigo-600 px-4 py-2 text-xs font-semibold text-white hover:bg-indigo-500 shadow-sm"
              >
                <Save className="h-4 w-4" />
                <span>Save Origin Coordinates</span>
              </button>
            )}
          </form>
        </div>

        {/* Distance Bands Table */}
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center space-x-2 mb-4">
            <Truck className="h-5 w-5 text-purple-600" />
            <h2 className="text-base font-bold text-slate-900">Active Delivery Distance Bands</h2>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                <tr>
                  <th className="pb-2.5">Band Name</th>
                  <th className="pb-2.5">Distance Slab</th>
                  <th className="pb-2.5">Delivery Fee</th>
                  <th className="pb-2.5">Free Above</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {bands.length === 0 ? (
                  <tr>
                    <td colSpan="4" className="py-6 text-center text-slate-400">
                      Standard delivery rate applies.
                    </td>
                  </tr>
                ) : (
                  bands.map((b) => (
                    <tr key={b.id} className="hover:bg-slate-50">
                      <td className="py-2.5 font-bold text-slate-800">{b.name}</td>
                      <td className="py-2.5 text-slate-600">
                        {b.min_distance_km} km – {b.max_distance_km || '∞'} km
                      </td>
                      <td className="py-2.5 font-bold text-slate-900">₹{parseFloat(b.delivery_fee || 0).toFixed(2)}</td>
                      <td className="py-2.5 font-semibold text-emerald-600">
                        {b.free_delivery_threshold ? `₹${b.free_delivery_threshold}` : 'N/A'}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
