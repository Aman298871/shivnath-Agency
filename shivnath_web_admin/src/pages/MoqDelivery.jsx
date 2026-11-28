import React, { useState, useEffect, useMemo } from 'react';
import {
  Layers, MapPin, Truck, Check, RefreshCw, AlertCircle, Save, Plus,
  Trash2, Edit, Sliders, CheckCircle2, ShieldCheck, XCircle, Navigation, Info
} from 'lucide-react';
import apiClient from '../api/client';
import Modal from '../components/common/Modal';
import { useAuth } from '../context/AuthContext';

// Standard Haversine distance calculation in kilometers
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the Earth in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

export default function MoqDelivery() {
  const { hasPermission } = useAuth();
  const [activeTab, setActiveTab] = useState('moq'); // 'moq' | 'origin' | 'bands' | 'simulator'

  // Data State
  const [rules, setRules] = useState([]);
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [franchises, setFranchises] = useState([]);
  const [bands, setBands] = useState([]);
  const [origin, setOrigin] = useState({
    name: 'Shivnath Agency Central Dispatch',
    address: 'Ekta Nagar, Pragati Nagar, LIC Colony, near Mowa Thana, Raipur, Chhattisgarh',
    city: 'Raipur',
    pincode: '492014',
    latitude: '21.267800',
    longitude: '81.671100',
    free_delivery_radius_km: 0.0,
    max_serviceable_radius_km: 25.0,
    default_delivery_charge: 30.0,
    is_active: true,
  });

  const [isLoading, setIsLoading] = useState(true);
  const [originMessage, setOriginMessage] = useState({ type: '', text: '' });
  const [isSavingOrigin, setIsSavingOrigin] = useState(false);

  // MOQ Rule Modal State (Create & Edit)
  const [isRuleModalOpen, setIsRuleModalOpen] = useState(false);
  const [editingRule, setEditingRule] = useState(null);
  const [ruleName, setRuleName] = useState('');
  const [ruleCategoryId, setRuleCategoryId] = useState('');
  const [ruleProductId, setRuleProductId] = useState('');
  const [ruleFranchiseId, setRuleFranchiseId] = useState('');
  const [ruleChannel, setRuleChannel] = useState('CUSTOMER');
  const [ruleSalesUnit, setRuleSalesUnit] = useState('CARTON');
  const [ruleUnitsPerCarton, setRuleUnitsPerCarton] = useState(24);
  const [ruleMinQty, setRuleMinQty] = useState(5);
  const [ruleStrictCarton, setRuleStrictCarton] = useState(true);
  const [ruleAllowOverride, setRuleAllowOverride] = useState(false);
  const [ruleMaxFranchiseMoq, setRuleMaxFranchiseMoq] = useState('');
  const [ruleIsActive, setRuleIsActive] = useState(true);
  const [isSavingRule, setIsSavingRule] = useState(false);
  const [ruleModalError, setRuleModalError] = useState('');

  // Add Distance Band Modal State
  const [isBandModalOpen, setIsBandModalOpen] = useState(false);
  const [bandName, setBandName] = useState('');
  const [bandMinKm, setBandMinKm] = useState('0');
  const [bandMaxKm, setBandMaxKm] = useState('5');
  const [bandCharge, setBandCharge] = useState('50');
  const [isSavingBand, setIsSavingBand] = useState(false);

  // Policy A Simulator State
  const [simProduct, setSimProduct] = useState('');
  const [simFranchiseMoq, setSimFranchiseMoq] = useState(5);

  // Distance & Tariff Simulator State
  const [simLat, setSimLat] = useState('21.2400');
  const [simLng, setSimLng] = useState('81.6300');
  const [simResult, setSimResult] = useState(null);

  const fetchData = async () => {
    try {
      setIsLoading(true);
      const [rulesRes, prodsRes, originRes, bandsRes, catsRes, franchisesRes] = await Promise.all([
        apiClient.get('/api/products/packaging-rules/'),
        apiClient.get('/api/products/'),
        apiClient.get('/api/billing/delivery/origin/'),
        apiClient.get('/api/billing/delivery/bands/'),
        apiClient.get('/api/products/categories/').catch(() => ({ data: [] })),
        apiClient.get('/api/accounts/franchises/').catch(() => ({ data: [] })),
      ]);

      setRules(rulesRes.data?.rules || rulesRes.data?.results || []);
      const prodList = prodsRes.data?.products || prodsRes.data?.results || (Array.isArray(prodsRes.data) ? prodsRes.data : []);
      setProducts(prodList);
      const fList = franchisesRes.data?.franchises || franchisesRes.data?.results || (Array.isArray(franchisesRes.data) ? franchisesRes.data : []);
      setFranchises(fList);
      if (originRes.data?.origin) {
        setOrigin(originRes.data.origin);
      }
      setBands(bandsRes.data?.bands || bandsRes.data?.results || []);
      setCategories(catsRes.data?.categories || catsRes.data?.results || (Array.isArray(catsRes.data) ? catsRes.data : []));

      if (prodList.length > 0 && !simProduct) {
        setSimProduct(prodList[0].id.toString());
      }
    } catch (err) {
      console.warn('MOQ Delivery fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // When category changes in rule modal, auto-update available products
  const availableProductsForCategory = useMemo(() => {
    if (!ruleCategoryId) return products;
    const catStr = String(ruleCategoryId).toLowerCase().trim();
    return (products || []).filter((p) => {
      const pCatId = p.category_ref_id?.toString() || p.category_id?.toString() || (typeof p.category === 'object' ? p.category?.id?.toString() : p.category?.toString());
      const pCatName = (typeof p.category === 'string' ? p.category : p.category_name || '').toLowerCase().trim();
      return pCatId === catStr || (pCatName && pCatName === catStr);
    });
  }, [products, ruleCategoryId]);

  // When product changes in rule modal, auto-fill pack size and name
  const handleProductSelect = (prodId) => {
    setRuleProductId(prodId);
    const prod = products.find((p) => p.id.toString() === prodId.toString());
    if (prod) {
      setRuleUnitsPerCarton(prod.units_per_case || prod.carton_pack_size || 24);
      const pName = String(prod.name || '').toLowerCase();
      if (prod.package_type === 'JAR' || pName.includes('jar')) {
        setRuleSalesUnit('JAR');
      } else {
        setRuleSalesUnit('CARTON');
      }
      if (!ruleName || ruleName.startsWith('MOQ Rule:')) {
        setRuleName(`MOQ Rule: ${prod.name}`);
      }
    }
  };

  const openAddRuleModal = () => {
    setEditingRule(null);
    setRuleName('');
    setRuleCategoryId('');
    setRuleProductId('');
    setRuleFranchiseId('');
    setRuleChannel('CUSTOMER');
    setRuleSalesUnit('CARTON');
    setRuleUnitsPerCarton(24);
    setRuleMinQty(5);
    setRuleStrictCarton(true);
    setRuleAllowOverride(false);
    setRuleMaxFranchiseMoq('');
    setRuleIsActive(true);
    setRuleModalError('');
    setIsRuleModalOpen(true);
  };

  const openEditRuleModal = (rule) => {
    setEditingRule(rule);
    setRuleName(rule.name || `Rule #${rule.id}`);
    setRuleCategoryId(rule.category_id || rule.category || '');
    setRuleProductId(rule.product_id || rule.product || '');
    setRuleFranchiseId(rule.franchise_id || rule.franchise || '');
    setRuleChannel(rule.applies_to || rule.channel || 'CUSTOMER');
    setRuleSalesUnit(rule.sales_unit || 'CARTON');
    setRuleUnitsPerCarton(rule.units_per_carton || 24);
    setRuleMinQty(rule.min_order_quantity || 1);
    setRuleStrictCarton(!rule.allow_partial_carton);
    setRuleAllowOverride(rule.allow_franchise_override || false);
    setRuleMaxFranchiseMoq(rule.max_franchise_moq || '');
    setRuleIsActive(rule.is_active ?? true);
    setRuleModalError('');
    setIsRuleModalOpen(true);
  };

  const handleSaveRule = async (e) => {
    e.preventDefault();
    setIsSavingRule(true);
    setRuleModalError('');

    try {
      const payload = {
        name: ruleName.trim() || `MOQ Rule #${Date.now()}`,
        product: ruleProductId ? parseInt(ruleProductId, 10) : null,
        category: ruleCategoryId ? parseInt(ruleCategoryId, 10) : null,
        franchise: ruleFranchiseId ? parseInt(ruleFranchiseId, 10) : null,
        applies_to: ruleChannel,
        channel: ruleChannel,
        sales_unit: ruleSalesUnit,
        units_per_carton: parseInt(ruleUnitsPerCarton, 10),
        min_order_quantity: parseInt(ruleMinQty, 10),
        allow_partial_carton: !ruleStrictCarton,
        allow_franchise_override: ruleAllowOverride,
        max_franchise_moq: ruleMaxFranchiseMoq ? parseInt(ruleMaxFranchiseMoq, 10) : null,
        is_active: ruleIsActive,
      };

      if (editingRule) {
        await apiClient.patch(`/api/products/packaging-rules/${editingRule.id}/`, payload);
      } else {
        await apiClient.post('/api/products/packaging-rules/', payload);
      }

      setIsRuleModalOpen(false);
      fetchData();
    } catch (err) {
      const msg = err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to save packaging rule.';
      setRuleModalError(msg);
    } finally {
      setIsSavingRule(false);
    }
  };

  const handleDeleteRule = async (ruleId) => {
    if (!window.confirm('Are you sure you want to delete this packaging rule?')) return;
    try {
      await apiClient.delete(`/api/products/packaging-rules/${ruleId}/`);
      fetchData();
    } catch (err) {
      alert(err.response?.data?.message || err.message || 'Failed to delete rule.');
    }
  };

  const handleToggleRuleActive = async (rule) => {
    try {
      await apiClient.patch(`/api/products/packaging-rules/${rule.id}/`, {
        is_active: !rule.is_active,
      });
      fetchData();
    } catch (err) {
      alert(err.response?.data?.message || err.message || 'Failed to update rule status.');
    }
  };

  const handleSaveOrigin = async (e) => {
    e.preventDefault();
    setIsSavingOrigin(true);
    setOriginMessage({ type: '', text: '' });

    try {
      await apiClient.post('/api/billing/delivery/origin/', {
        ...origin,
        latitude: parseFloat(origin.latitude),
        longitude: parseFloat(origin.longitude),
        free_delivery_radius_km: parseFloat(origin.free_delivery_radius_km || 0),
        max_serviceable_radius_km: parseFloat(origin.max_serviceable_radius_km || 25),
        default_delivery_charge: parseFloat(origin.default_delivery_charge || 30),
      });

      setOriginMessage({ type: 'success', text: 'Central Dispatch Depot settings saved successfully.' });
      fetchData();
      setTimeout(() => setOriginMessage({ type: '', text: '' }), 3000);
    } catch (err) {
      setOriginMessage({
        type: 'error',
        text: err.response?.data?.message || err.message || 'Failed to update dispatch origin.',
      });
    } finally {
      setIsSavingOrigin(false);
    }
  };

  const handleAddBand = async (e) => {
    e.preventDefault();
    setIsSavingBand(true);
    try {
      await apiClient.post('/api/billing/delivery/bands/', {
        name: bandName.trim() || `${bandMinKm}-${bandMaxKm} km Band`,
        min_distance_km: parseFloat(bandMinKm),
        max_distance_km: parseFloat(bandMaxKm),
        delivery_charge: parseFloat(bandCharge),
        is_active: true,
        is_supported: true,
      });
      setIsBandModalOpen(false);
      setBandName('');
      setBandMinKm('0');
      setBandMaxKm('5');
      setBandCharge('50');
      fetchData();
    } catch (err) {
      alert(err.response?.data?.message || err.message || 'Failed to create distance band.');
    } finally {
      setIsSavingBand(false);
    }
  };

  const handleDeleteBand = async (bandId) => {
    if (!window.confirm('Delete this distance pricing band?')) return;
    try {
      await apiClient.delete(`/api/billing/delivery/bands/${bandId}/`);
      fetchData();
    } catch (err) {
      alert(err.response?.data?.message || err.message || 'Failed to delete band.');
    }
  };

  // Run Delivery Tariff Simulator
  const handleRunDeliverySim = () => {
    const lat1 = parseFloat(origin.latitude || 21.2678);
    const lon1 = parseFloat(origin.longitude || 81.6711);
    const lat2 = parseFloat(simLat);
    const lon2 = parseFloat(simLng);

    if (isNaN(lat2) || isNaN(lon2)) {
      alert('Please enter valid numeric latitude and longitude coordinates.');
      return;
    }

    const distance = calculateHaversineDistance(lat1, lon1, lat2, lon2);
    const maxRadius = parseFloat(origin.max_serviceable_radius_km || 25);
    const freeRadius = parseFloat(origin.free_delivery_radius_km || 0);
    const fallbackFee = parseFloat(origin.default_delivery_charge || 30);

    let fee = fallbackFee;
    let status = 'SERVICEABLE';
    let matchedBand = null;

    if (distance > maxRadius) {
      status = 'OUT_OF_RANGE';
      fee = null;
    } else if (distance <= freeRadius) {
      status = 'FREE_DELIVERY';
      fee = 0.0;
    } else {
      // Find matching distance band
      const sortedBands = [...bands].filter((b) => b.is_active !== false).sort((a, b) => a.min_distance_km - b.min_distance_km);
      for (const b of sortedBands) {
        if (distance >= b.min_distance_km && distance < b.max_distance_km) {
          matchedBand = b;
          fee = parseFloat(b.delivery_charge);
          break;
        }
      }
    }

    setSimResult({
      distance: distance.toFixed(2),
      status,
      fee,
      matchedBand: matchedBand ? matchedBand.name || matchedBand.label : 'Default Fallback Tariff',
    });
  };

  // Policy A Simulator Computation
  const policyASimData = useMemo(() => {
    if (!simProduct) return null;
    const prod = products.find((p) => p.id.toString() === simProduct.toString());
    const rule = rules.find((r) => (r.product_id || r.product)?.toString() === simProduct.toString());

    const baselineMoq = rule?.min_order_quantity || 1;
    const allowOverride = rule?.allow_franchise_override ?? true;
    const maxFranchiseMoq = rule?.max_franchise_moq;
    const packSize = rule?.units_per_carton || prod?.units_per_case || 24;
    const strictCarton = rule ? !rule.allow_partial_carton : true;

    const fMoq = parseInt(simFranchiseMoq || 1, 10);
    const effectiveMoq = Math.max(baselineMoq, fMoq);

    let isValid = true;
    let message = 'Franchise MOQ is compliant with Policy A.';

    if (!allowOverride && fMoq !== baselineMoq) {
      isValid = false;
      message = 'Admin policy prohibits franchise overrides for this product.';
    } else if (fMoq < baselineMoq) {
      isValid = false;
      message = `Franchise MOQ (${fMoq}) cannot be lower than Admin mandatory baseline (${baselineMoq}).`;
    } else if (maxFranchiseMoq && fMoq > maxFranchiseMoq) {
      isValid = false;
      message = `Franchise MOQ (${fMoq}) exceeds maximum company ceiling (${maxFranchiseMoq}).`;
    }

    return {
      prod,
      rule,
      baselineMoq,
      allowOverride,
      maxFranchiseMoq,
      packSize,
      strictCarton,
      fMoq,
      effectiveMoq,
      isValid,
      message,
    };
  }, [simProduct, simFranchiseMoq, rules, products]);

  const activeRulesCount = rules.filter((r) => r.is_active !== false).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div className="flex items-center space-x-3">
            <h1 className="text-2xl font-bold tracking-tight text-slate-900">
              MOQ & Delivery Logistics Control
            </h1>
            <span className="inline-flex items-center rounded-full bg-sky-50 px-2.5 py-0.5 text-xs font-bold text-sky-700 border border-sky-200">
              {activeRulesCount} Active Rules
            </span>
          </div>
          <p className="text-sm text-slate-500">
            Enforce Policy A packaging controls, dispatch depot coordinates & distance-tariff slabs
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

      {/* Navigation Tabs */}
      <div className="flex space-x-2 border-b border-slate-200 text-xs font-semibold">
        <button
          onClick={() => setActiveTab('moq')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 ${
            activeTab === 'moq'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Layers className="h-4 w-4" />
          <span>MOQ Packaging Rules</span>
        </button>

        <button
          onClick={() => setActiveTab('origin')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 ${
            activeTab === 'origin'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <MapPin className="h-4 w-4" />
          <span>Dispatch Depot & Radius</span>
        </button>

        <button
          onClick={() => setActiveTab('bands')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 ${
            activeTab === 'bands'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Truck className="h-4 w-4" />
          <span>Distance Tariff Slabs</span>
        </button>

        <button
          onClick={() => setActiveTab('simulator')}
          className={`pb-3 px-3 transition-colors flex items-center space-x-1.5 border-b-2 ${
            activeTab === 'simulator'
              ? 'border-sky-600 text-sky-600 font-bold'
              : 'border-transparent text-slate-500 hover:text-slate-900'
          }`}
        >
          <Sliders className="h-4 w-4" />
          <span>Policy & Tariff Simulator</span>
        </button>
      </div>

      {/* TAB 1: MOQ PACKAGING RULES */}
      {activeTab === 'moq' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-bold text-slate-900">Configured Minimum Order Rules</h2>
            {hasPermission('moq', 'create') && (
              <button
                onClick={openAddRuleModal}
                className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
              >
                <Plus className="h-4 w-4" />
                <span>Create MOQ Rule</span>
              </button>
            )}
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                  <tr>
                    <th className="pb-3">Rule Name & Target</th>
                    <th className="pb-3">Scope / Franchise</th>
                    <th className="pb-3">Channel</th>
                    <th className="pb-3">Min Order Qty (MOQ)</th>
                    <th className="pb-3">Pack Multiple</th>
                    <th className="pb-3">Franchise Override</th>
                    <th className="pb-3">Status</th>
                    <th className="pb-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {rules.length === 0 ? (
                    <tr>
                      <td colSpan="8" className="py-12 text-center text-slate-400">
                        No packaging rules found. Click &quot;Create MOQ Rule&quot; to configure.
                      </td>
                    </tr>
                  ) : (
                    rules.map((r) => {
                      const prod = products.find((p) => p.id === (r.product_id || r.product));
                      const isStrict = !r.allow_partial_carton;
                      const isActive = r.is_active !== false;

                      return (
                        <tr key={r.id} className="hover:bg-slate-50/80 transition-colors">
                          <td className="py-3.5">
                            <div className="font-bold text-slate-900">{r.name || `Rule #${r.id}`}</div>
                            <div className="text-[11px] text-slate-500">
                              {prod ? prod.name : r.category_name || r.category || 'All Products'}
                            </div>
                          </td>
                          <td className="py-3.5">
                            {r.is_baseline || !r.franchise ? (
                              <span className="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold bg-slate-100 text-slate-700 border border-slate-200">
                                Company Baseline
                              </span>
                            ) : (
                              <span className="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold bg-purple-50 text-purple-700 border border-purple-200">
                                {r.franchise_name || `Franchise #${r.franchise}`}
                              </span>
                            )}
                          </td>
                          <td className="py-3.5 font-semibold text-slate-700">
                            {r.applies_to || r.channel || 'CUSTOMER'}
                          </td>
                          <td className="py-3.5 font-bold text-sky-700">
                            {r.min_order_quantity} {r.sales_unit || 'CARTON'}(s)
                          </td>
                          <td className="py-3.5">
                            <span
                              className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                                isStrict
                                  ? 'bg-indigo-50 text-indigo-700 border border-indigo-200'
                                  : 'bg-amber-50 text-amber-700 border border-amber-200'
                              }`}
                            >
                              {isStrict ? `Strict Multiple (${r.units_per_carton}/ctn)` : 'Loose Allowed'}
                            </span>
                          </td>
                          <td className="py-3.5 text-slate-600">
                            {r.allow_franchise_override ? (
                              <span className="text-emerald-700 font-medium">
                                Allowed (Max: {r.max_franchise_moq || 'Uncapped'})
                              </span>
                            ) : (
                              <span className="text-slate-400">Prohibited</span>
                            )}
                          </td>
                          <td className="py-3.5">
                            <button
                              onClick={() => handleToggleRuleActive(r)}
                              className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold transition-colors ${
                                isActive
                                  ? 'bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100'
                                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                              }`}
                            >
                              {isActive ? 'Active' : 'Disabled'}
                            </button>
                          </td>
                          <td className="py-3.5 text-right space-x-2">
                            <button
                              onClick={() => openEditRuleModal(r)}
                              className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                            >
                              <Edit className="h-3.5 w-3.5" />
                              <span>Edit</span>
                            </button>

                            {hasPermission('moq', 'delete') && (
                              <button
                                onClick={() => handleDeleteRule(r.id)}
                                className="inline-flex items-center space-x-1 rounded-md bg-rose-50 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-100 border border-rose-200"
                              >
                                <Trash2 className="h-3.5 w-3.5" />
                                <span>Delete</span>
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
        </div>
      )}

      {/* TAB 2: DISPATCH DEPOT & RADIUS */}
      {activeTab === 'origin' && (
        <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm max-w-3xl">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h2 className="text-base font-bold text-slate-900">Authoritative Central Dispatch Depot</h2>
              <p className="text-xs text-slate-500">
                Ground zero coordinates for Haversine distance calculations and delivery service boundaries
              </p>
            </div>
            <MapPin className="h-6 w-6 text-sky-600" />
          </div>

          {originMessage.text && (
            <div
              className={`mb-6 flex items-center space-x-2 rounded-lg p-3 text-xs border ${
                originMessage.type === 'success'
                  ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                  : 'bg-rose-50 text-rose-800 border-rose-200'
              }`}
            >
              {originMessage.type === 'success' ? (
                <CheckCircle2 className="h-4 w-4 shrink-0" />
              ) : (
                <AlertCircle className="h-4 w-4 shrink-0" />
              )}
              <span>{originMessage.text}</span>
            </div>
          )}

          <form onSubmit={handleSaveOrigin} className="space-y-4 text-xs">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div className="sm:col-span-2">
                <label className="block font-semibold text-slate-700">Depot Facility Name</label>
                <input
                  type="text"
                  required
                  value={origin.name || ''}
                  onChange={(e) => setOrigin({ ...origin, name: e.target.value })}
                  placeholder="e.g. Shivnath Agency Central Dispatch"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div className="sm:col-span-2">
                <label className="block font-semibold text-slate-700">Physical Address</label>
                <input
                  type="text"
                  required
                  value={origin.address || ''}
                  onChange={(e) => setOrigin({ ...origin, address: e.target.value })}
                  placeholder="Full street address and landmarks"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">City</label>
                <input
                  type="text"
                  value={origin.city || 'Raipur'}
                  onChange={(e) => setOrigin({ ...origin, city: e.target.value })}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Pincode</label>
                <input
                  type="text"
                  value={origin.pincode || '492014'}
                  onChange={(e) => setOrigin({ ...origin, pincode: e.target.value })}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Latitude Coordinate</label>
                <input
                  type="number"
                  step="0.000001"
                  required
                  value={origin.latitude || ''}
                  onChange={(e) => setOrigin({ ...origin, latitude: e.target.value })}
                  placeholder="21.267800"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-mono"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Longitude Coordinate</label>
                <input
                  type="number"
                  step="0.000001"
                  required
                  value={origin.longitude || ''}
                  onChange={(e) => setOrigin({ ...origin, longitude: e.target.value })}
                  placeholder="81.671100"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-mono"
                />
              </div>

              {/* Free Delivery Radius Slider + Input */}
              <div>
                <div className="flex items-center justify-between">
                  <label className="font-semibold text-slate-700">Free Delivery Radius (km)</label>
                  <span className="font-bold text-sky-600">{origin.free_delivery_radius_km || 0} km</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="20"
                  step="0.5"
                  value={origin.free_delivery_radius_km || 0}
                  onChange={(e) =>
                    setOrigin({ ...origin, free_delivery_radius_km: parseFloat(e.target.value) })
                  }
                  className="mt-2 w-full accent-sky-600"
                />
                <p className="text-[10px] text-slate-400 mt-0.5">Orders within this distance have ₹0 delivery fee</p>
              </div>

              {/* Maximum Serviceable Radius Slider + Input */}
              <div>
                <div className="flex items-center justify-between">
                  <label className="font-semibold text-slate-700">Maximum Serviceable Radius (km)</label>
                  <span className="font-bold text-rose-600">{origin.max_serviceable_radius_km || 25} km</span>
                </div>
                <input
                  type="range"
                  min="5"
                  max="100"
                  step="1"
                  value={origin.max_serviceable_radius_km || 25}
                  onChange={(e) =>
                    setOrigin({ ...origin, max_serviceable_radius_km: parseFloat(e.target.value) })
                  }
                  className="mt-2 w-full accent-rose-600"
                />
                <p className="text-[10px] text-slate-400 mt-0.5">Orders beyond this cutoff are rejected as out of range</p>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Default Fallback Delivery Fee (₹)</label>
                <input
                  type="number"
                  step="1"
                  required
                  value={origin.default_delivery_charge || 30}
                  onChange={(e) =>
                    setOrigin({ ...origin, default_delivery_charge: parseFloat(e.target.value) })
                  }
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div className="flex items-center space-x-2 pt-6">
                <input
                  type="checkbox"
                  id="originActive"
                  checked={origin.is_active !== false}
                  onChange={(e) => setOrigin({ ...origin, is_active: e.target.checked })}
                  className="h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500"
                />
                <label htmlFor="originActive" className="font-semibold text-slate-700">
                  Enforce Origin Facility Boundaries
                </label>
              </div>
            </div>

            <div className="flex justify-end pt-4 border-t border-slate-100">
              <button
                type="submit"
                disabled={isSavingOrigin}
                className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors disabled:opacity-50"
              >
                <Save className="h-4 w-4" />
                <span>{isSavingOrigin ? 'Saving...' : 'Save Depot Origin Configuration'}</span>
              </button>
            </div>
          </form>
        </div>
      )}

      {/* TAB 3: DISTANCE TARIFF SLABS */}
      {activeTab === 'bands' && (
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-bold text-slate-900">Configured Distance Tariff Bands</h2>
            {hasPermission('billing', 'edit') && (
              <button
                onClick={() => setIsBandModalOpen(true)}
                className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
              >
                <Plus className="h-4 w-4" />
                <span>Add Tariff Band</span>
              </button>
            )}
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
                  <tr>
                    <th className="pb-3">Tariff Slab Name</th>
                    <th className="pb-3">Min Distance</th>
                    <th className="pb-3">Max Distance</th>
                    <th className="pb-3">Delivery Fee (₹)</th>
                    <th className="pb-3">Status</th>
                    <th className="pb-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {bands.length === 0 ? (
                    <tr>
                      <td colSpan="6" className="py-12 text-center text-slate-400">
                        No distance tariff bands found.
                      </td>
                    </tr>
                  ) : (
                    bands.map((b) => (
                      <tr key={b.id} className="hover:bg-slate-50/80 transition-colors">
                        <td className="py-3.5 font-bold text-slate-900">{b.name || b.label}</td>
                        <td className="py-3.5 text-slate-600">{b.min_distance_km} km</td>
                        <td className="py-3.5 text-slate-600">{b.max_distance_km} km</td>
                        <td className="py-3.5 font-bold text-emerald-600">₹{parseFloat(b.delivery_charge).toFixed(2)}</td>
                        <td className="py-3.5">
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
                            Active
                          </span>
                        </td>
                        <td className="py-3.5 text-right">
                          <button
                            onClick={() => handleDeleteBand(b.id)}
                            className="inline-flex items-center space-x-1 rounded-md bg-rose-50 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-100 border border-rose-200"
                          >
                            <Trash2 className="h-3.5 w-3.5" />
                            <span>Delete</span>
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* TAB 4: SIMULATOR */}
      {activeTab === 'simulator' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Policy A Invariant Simulator */}
          <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm space-y-4">
            <div className="flex items-center space-x-2">
              <ShieldCheck className="h-5 w-5 text-sky-600" />
              <h2 className="text-base font-bold text-slate-900">Policy A MOQ Invariant Simulator</h2>
            </div>
            <p className="text-xs text-slate-500">
              Evaluates: <code>Effective MOQ = max(Admin Baseline, Franchise MOQ)</code>
            </p>

            <div className="space-y-3 text-xs">
              <div>
                <label className="block font-semibold text-slate-700">Select Product Catalog SKU</label>
                <select
                  value={simProduct}
                  onChange={(e) => setSimProduct(e.target.value)}
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
                <label className="block font-semibold text-slate-700">Simulated Franchise Requested MOQ</label>
                <input
                  type="number"
                  min="1"
                  value={simFranchiseMoq}
                  onChange={(e) => setSimFranchiseMoq(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              {policyASimData && (
                <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 space-y-2 mt-4">
                  <div className="flex justify-between">
                    <span className="text-slate-500">Admin Mandatory Baseline:</span>
                    <span className="font-bold text-slate-900">{policyASimData.baselineMoq} cartons</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500">Franchise Override Allowed:</span>
                    <span className="font-semibold text-slate-900">
                      {policyASimData.allowOverride ? 'YES' : 'NO'}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500">Maximum Franchise Ceiling:</span>
                    <span className="font-semibold text-slate-900">
                      {policyASimData.maxFranchiseMoq || 'Uncapped'}
                    </span>
                  </div>
                  <div className="border-t border-slate-200 pt-2 flex justify-between items-center">
                    <span className="font-bold text-slate-800">Effective Enforced MOQ:</span>
                    <span className="text-base font-bold text-sky-700">
                      {policyASimData.effectiveMoq} cartons ({policyASimData.effectiveMoq * policyASimData.packSize} bottles)
                    </span>
                  </div>

                  <div
                    className={`mt-2 flex items-center space-x-1.5 rounded-lg p-2.5 text-[11px] font-semibold border ${
                      policyASimData.isValid
                        ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                        : 'bg-rose-50 text-rose-800 border-rose-200'
                    }`}
                  >
                    {policyASimData.isValid ? (
                      <CheckCircle2 className="h-4 w-4 shrink-0 text-emerald-600" />
                    ) : (
                      <XCircle className="h-4 w-4 shrink-0 text-rose-600" />
                    )}
                    <span>{policyASimData.message}</span>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Delivery Tariff & Haversine Distance Simulator */}
          <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm space-y-4">
            <div className="flex items-center space-x-2">
              <Navigation className="h-5 w-5 text-sky-600" />
              <h2 className="text-base font-bold text-slate-900">Delivery Distance & Tariff Simulator</h2>
            </div>
            <p className="text-xs text-slate-500">
              Calculate exact customer delivery fee using Haversine algorithm from central origin
            </p>

            <div className="space-y-3 text-xs">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-semibold text-slate-700">Customer Latitude</label>
                  <input
                    type="number"
                    step="0.0001"
                    value={simLat}
                    onChange={(e) => setSimLat(e.target.value)}
                    className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-mono"
                  />
                </div>
                <div>
                  <label className="block font-semibold text-slate-700">Customer Longitude</label>
                  <input
                    type="number"
                    step="0.0001"
                    value={simLng}
                    onChange={(e) => setSimLng(e.target.value)}
                    className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-mono"
                  />
                </div>
              </div>

              <button
                onClick={handleRunDeliverySim}
                className="w-full inline-flex items-center justify-center space-x-1.5 rounded-lg bg-sky-600 py-2 font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
              >
                <span>Calculate Distance & Tariff</span>
              </button>

              {simResult && (
                <div className="rounded-xl border border-slate-200 bg-slate-50 p-4 space-y-2 mt-4">
                  <div className="flex justify-between">
                    <span className="text-slate-500">Haversine Distance:</span>
                    <span className="font-bold text-slate-900">{simResult.distance} km</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500">Matched Tariff Slab:</span>
                    <span className="font-semibold text-slate-900">{simResult.matchedBand}</span>
                  </div>
                  <div className="border-t border-slate-200 pt-2 flex justify-between items-center">
                    <span className="font-bold text-slate-800">Final Delivery Tariff:</span>
                    <span className="text-base font-bold text-emerald-600">
                      {simResult.fee !== null ? `₹${simResult.fee.toFixed(2)}` : 'OUT OF SERVICE'}
                    </span>
                  </div>

                  <div
                    className={`mt-2 flex items-center space-x-1.5 rounded-lg p-2.5 text-[11px] font-semibold border ${
                      simResult.status === 'OUT_OF_RANGE'
                        ? 'bg-rose-50 text-rose-800 border-rose-200'
                        : simResult.status === 'FREE_DELIVERY'
                        ? 'bg-emerald-50 text-emerald-800 border-emerald-200'
                        : 'bg-sky-50 text-sky-800 border-sky-200'
                    }`}
                  >
                    <Info className="h-4 w-4 shrink-0" />
                    <span>
                      {simResult.status === 'OUT_OF_RANGE'
                        ? 'Address is outside maximum serviceable cutoff boundary.'
                        : simResult.status === 'FREE_DELIVERY'
                        ? 'Address qualifies for Free Delivery (within 0 km radius).'
                        : 'Serviceable location under standard distance band tariffs.'}
                    </span>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* CREATE / EDIT MOQ RULE MODAL */}
      {isRuleModalOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsRuleModalOpen(false)}
          title={editingRule ? `Edit Rule: ${editingRule.name}` : 'Create Minimum Order Packaging Rule'}
          maxWidth="max-w-lg"
        >
          <form onSubmit={handleSaveRule} className="space-y-4 text-xs">
            {ruleModalError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-800 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{ruleModalError}</span>
              </div>
            )}

            <div>
              <label className="block font-semibold text-slate-700">Rule Display Name</label>
              <input
                type="text"
                required
                value={ruleName}
                onChange={(e) => setRuleName(e.target.value)}
                placeholder="e.g. 500ml Retail Cartons MOQ"
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Rule Scope / Target Franchise</label>
              <select
                value={ruleFranchiseId}
                onChange={(e) => setRuleFranchiseId(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              >
                <option value="">Company Baseline (Applies to all franchises)</option>
                {franchises.map((f) => (
                  <option key={f.id} value={f.id}>
                    Franchise: {f.business_name} ({f.dealer_code || f.city || ''})
                  </option>
                ))}
              </select>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Category Filter</label>
                <select
                  value={ruleCategoryId}
                  onChange={(e) => setRuleCategoryId(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="">All Product Categories</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Specific Product SKU</label>
                <select
                  value={ruleProductId}
                  onChange={(e) => handleProductSelect(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="">Apply to Category Baseline</option>
                  {availableProductsForCategory.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Sales / Ordering Unit</label>
                <select
                  value={ruleSalesUnit}
                  onChange={(e) => setRuleSalesUnit(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="CARTON">CARTON</option>
                  <option value="BOTTLE">BOTTLE</option>
                  <option value="JAR">JAR</option>
                </select>
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Units Per Carton</label>
                <input
                  type="number"
                  min="1"
                  required
                  value={ruleUnitsPerCarton}
                  onChange={(e) => setRuleUnitsPerCarton(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Minimum Order Quantity (MOQ)</label>
                <input
                  type="number"
                  min="1"
                  required
                  value={ruleMinQty}
                  onChange={(e) => setRuleMinQty(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-bold"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Target Channel</label>
                <select
                  value={ruleChannel}
                  onChange={(e) => setRuleChannel(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="CUSTOMER">Retail Customers</option>
                  <option value="FRANCHISE">Dealers / Franchises</option>
                  <option value="ALL">All Order Channels</option>
                </select>
              </div>
            </div>

            <div className="border-t border-slate-100 pt-3 space-y-2">
              <div className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  id="strictCarton"
                  checked={ruleStrictCarton}
                  onChange={(e) => setRuleStrictCarton(e.target.checked)}
                  className="h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500"
                />
                <label htmlFor="strictCarton" className="font-semibold text-slate-700">
                  Enforce Strict Carton Multiples (Disallow partial carton opening)
                </label>
              </div>

              <div className="flex items-center space-x-2">
                <input
                  type="checkbox"
                  id="allowOverride"
                  checked={ruleAllowOverride}
                  onChange={(e) => setRuleAllowOverride(e.target.checked)}
                  className="h-4 w-4 rounded border-slate-300 text-sky-600 focus:ring-sky-500"
                />
                <label htmlFor="allowOverride" className="font-semibold text-slate-700">
                  Allow Serving Franchises to Increase MOQ Override
                </label>
              </div>

              {ruleAllowOverride && (
                <div className="pl-6 pt-1">
                  <label className="block font-semibold text-slate-700">
                    Maximum Franchise Override Ceiling (Cartons)
                  </label>
                  <input
                    type="number"
                    min={ruleMinQty}
                    value={ruleMaxFranchiseMoq}
                    onChange={(e) => setRuleMaxFranchiseMoq(e.target.value)}
                    placeholder="e.g. 20 (leave blank for unlimited)"
                    className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                  />
                </div>
              )}
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsRuleModalOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSavingRule}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSavingRule ? 'Saving...' : editingRule ? 'Update Rule' : 'Create Rule'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* ADD DISTANCE BAND MODAL */}
      {isBandModalOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsBandModalOpen(false)}
          title="Add Distance Tariff Slab"
          maxWidth="max-w-md"
        >
          <form onSubmit={handleAddBand} className="space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-slate-700">Band Display Name</label>
              <input
                type="text"
                value={bandName}
                onChange={(e) => setBandName(e.target.value)}
                placeholder="e.g. Outskirts (5-10 km)"
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Min Distance (km)</label>
                <input
                  type="number"
                  step="0.1"
                  required
                  value={bandMinKm}
                  onChange={(e) => setBandMinKm(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block font-semibold text-slate-700">Max Distance (km)</label>
                <input
                  type="number"
                  step="0.1"
                  required
                  value={bandMaxKm}
                  onChange={(e) => setBandMaxKm(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>

              <div className="col-span-2">
                <label className="block font-semibold text-slate-700">Delivery Tariff (₹)</label>
                <input
                  type="number"
                  step="1"
                  required
                  value={bandCharge}
                  onChange={(e) => setBandCharge(e.target.value)}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsBandModalOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSavingBand}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSavingBand ? 'Creating...' : 'Save Band'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
