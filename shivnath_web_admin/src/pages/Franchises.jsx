import React, { useState, useEffect } from 'react';
import { Store, Search, ShieldCheck, Check, X, FileText, CreditCard, RefreshCw, AlertCircle } from 'lucide-react';
import StatusBadge from '../components/common/StatusBadge';
import Modal from '../components/common/Modal';
import apiClient from '../api/client';
import { useAuth } from '../context/AuthContext';

export default function Franchises() {
  const { hasPermission } = useAuth();
  const [franchises, setFranchises] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedDealer, setSelectedDealer] = useState(null);
  const [actionError, setActionError] = useState('');

  const fetchFranchises = async () => {
    try {
      setIsLoading(true);
      const res = await apiClient.get('/api/accounts/franchises/');
      setFranchises(res.data?.franchises || res.data?.results || res.data || []);
    } catch (err) {
      console.warn('Franchises fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchFranchises();
  }, []);

  const handleUpdateStatus = async (dealerId, newStatus) => {
    setActionError('');
    try {
      await apiClient.patch(`/api/accounts/franchises/${dealerId}/`, {
        status: newStatus,
      });
      setSelectedDealer(null);
      fetchFranchises();
    } catch (err) {
      const msg = err.response?.data?.error || err.message || 'Status update failed';
      setActionError(msg);
    }
  };

  const filtered = franchises.filter((f) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      f.franchise_name?.toLowerCase().includes(q) ||
      f.owner_name?.toLowerCase().includes(q) ||
      f.phone?.includes(q) ||
      f.city?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Franchise & Dealer Network</h1>
          <p className="text-sm text-slate-500">Manage B2B dealers, KYC approvals, and credit accounts</p>
        </div>

        <button
          onClick={fetchFranchises}
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
            placeholder="Search dealers by business name, proprietor, city, or phone..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>
      </div>

      {/* Franchises Table */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Franchise / Dealer</th>
                <th className="pb-3">Proprietor</th>
                <th className="pb-3">Location / City</th>
                <th className="pb-3">Credit Limit</th>
                <th className="pb-3">Outstanding</th>
                <th className="pb-3">KYC Status</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="7" className="py-12 text-center text-slate-400">
                    No franchise records found.
                  </td>
                </tr>
              ) : (
                filtered.map((f) => (
                  <tr key={f.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 font-bold text-slate-900">
                      {f.franchise_name || f.business_name || 'Shivnath Outlet'}
                    </td>
                    <td className="py-3.5 text-slate-700">{f.owner_name || f.contact_person || 'Dealer'}</td>
                    <td className="py-3.5 text-slate-500">{f.city || f.district || 'Chhattisgarh'}</td>
                    <td className="py-3.5 font-semibold text-slate-900">
                      ₹{parseFloat(f.credit_limit || 0).toLocaleString('en-IN')}
                    </td>
                    <td className="py-3.5 font-bold text-rose-600">
                      ₹{parseFloat(f.current_outstanding || f.outstanding_balance || 0).toLocaleString('en-IN')}
                    </td>
                    <td className="py-3.5">
                      <StatusBadge status={f.status || 'PENDING'} />
                    </td>
                    <td className="py-3.5 text-right">
                      <button
                        onClick={() => setSelectedDealer(f)}
                        className="inline-flex items-center space-x-1 rounded-md bg-sky-50 px-2.5 py-1 text-xs font-semibold text-sky-600 hover:bg-sky-100"
                      >
                        <ShieldCheck className="h-3.5 w-3.5" />
                        <span>KYC Review</span>
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* KYC Review & Credit Modal */}
      {selectedDealer && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedDealer(null)}
          title={`KYC & Credit Profile — ${selectedDealer.franchise_name || 'Dealer'}`}
          maxWidth="max-w-xl"
        >
          <div className="space-y-4 text-xs">
            {actionError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4" />
                <span>{actionError}</span>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3 rounded-xl bg-slate-50 p-4 border border-slate-100">
              <div>
                <p className="text-[10px] uppercase font-semibold text-slate-400">GSTIN / Registration</p>
                <p className="font-mono font-bold text-slate-800 mt-0.5">{selectedDealer.gstin || 'Unregistered'}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-semibold text-slate-400">FSSAI License</p>
                <p className="font-mono font-bold text-slate-800 mt-0.5">{selectedDealer.fssai_license || 'Verified on file'}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-semibold text-slate-400">Dealer Credit Limit</p>
                <p className="font-bold text-slate-900 mt-0.5">₹{parseFloat(selectedDealer.credit_limit || 0).toLocaleString('en-IN')}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-semibold text-slate-400">Current Outstanding</p>
                <p className="font-bold text-rose-600 mt-0.5">₹{parseFloat(selectedDealer.current_outstanding || 0).toLocaleString('en-IN')}</p>
              </div>
            </div>

            {hasPermission('franchises', 'edit') && (
              <div className="border-t border-slate-100 pt-4 flex items-center justify-end space-x-3">
                <button
                  onClick={() => handleUpdateStatus(selectedDealer.id, 'rejected')}
                  className="inline-flex items-center space-x-1.5 rounded-lg border border-rose-200 bg-rose-50 px-3.5 py-2 text-xs font-semibold text-rose-700 hover:bg-rose-100"
                >
                  <X className="h-4 w-4" />
                  <span>Reject Application</span>
                </button>
                <button
                  onClick={() => handleUpdateStatus(selectedDealer.id, 'approved')}
                  className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-600 px-3.5 py-2 text-xs font-semibold text-white hover:bg-emerald-500 shadow-sm"
                >
                  <Check className="h-4 w-4" />
                  <span>Approve & Activate Dealer</span>
                </button>
              </div>
            )}
          </div>
        </Modal>
      )}
    </div>
  );
}
