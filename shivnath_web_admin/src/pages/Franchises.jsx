import React, { useState, useEffect } from 'react';
import { Store, Search, ShieldCheck, Check, X, FileText, CreditCard, RefreshCw, AlertCircle, ExternalLink, Phone, Mail, MapPin, Building } from 'lucide-react';
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
      if (newStatus === 'approved') {
        await apiClient.post(`/api/accounts/franchises/${dealerId}/approve/`, {
          override_reason: 'Approved via Web Admin Portal',
        });
      } else if (newStatus === 'rejected') {
        await apiClient.post(`/api/accounts/franchises/${dealerId}/reject/`, {
          rejection_reason: 'Rejected via Web Admin Portal',
        });
      } else {
        await apiClient.patch(`/api/accounts/franchises/${dealerId}/`, {
          status: newStatus,
        });
      }
      setSelectedDealer(null);
      fetchFranchises();
    } catch (err) {
      const msg = err.response?.data?.message || err.response?.data?.error || err.message || 'Status update failed';
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
          title={`KYC & Credit Profile — ${selectedDealer.business_name || selectedDealer.franchise_name || 'Dealer'}`}
          maxWidth="max-w-2xl"
        >
          <div className="space-y-4 text-xs max-h-[75vh] overflow-y-auto pr-1">
            {actionError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{actionError}</span>
              </div>
            )}

            {/* Franchise Identity & Contact Header */}
            <div className="rounded-xl bg-slate-50 p-4 border border-slate-100 space-y-2">
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="font-bold text-slate-900 text-sm">{selectedDealer.business_name || selectedDealer.franchise_name}</h3>
                  <p className="text-slate-600 font-medium mt-0.5">Proprietor: {selectedDealer.owner_name || 'N/A'}</p>
                </div>
                <StatusBadge status={selectedDealer.status || 'pending'} type="franchise" />
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-[11px] pt-1 text-slate-600">
                <div className="flex items-center gap-1.5">
                  <Phone className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                  <span>{selectedDealer.phone || 'No phone'}</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <Mail className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                  <span>{selectedDealer.email || 'No email'}</span>
                </div>
                <div className="flex items-center gap-1.5 sm:col-span-2">
                  <MapPin className="h-3.5 w-3.5 text-slate-400 shrink-0" />
                  <span>{selectedDealer.address ? `${selectedDealer.address}, ` : ''}{selectedDealer.city || ''} {selectedDealer.territory ? `(${selectedDealer.territory})` : ''}</span>
                </div>
              </div>
            </div>

            {/* Compliance & Financial Details */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
              <div className="rounded-lg bg-slate-50 p-2.5 border border-slate-100">
                <p className="text-[10px] uppercase font-semibold text-slate-400">GSTIN</p>
                <p className="font-mono font-bold text-slate-800 mt-0.5 truncate">{selectedDealer.gst_number || selectedDealer.gstin || 'Unregistered'}</p>
              </div>
              <div className="rounded-lg bg-slate-50 p-2.5 border border-slate-100">
                <p className="text-[10px] uppercase font-semibold text-slate-400">PAN Number</p>
                <p className="font-mono font-bold text-slate-800 mt-0.5">{selectedDealer.pan || selectedDealer.pan_number || 'N/A'}</p>
              </div>
              <div className="rounded-lg bg-slate-50 p-2.5 border border-slate-100">
                <p className="text-[10px] uppercase font-semibold text-slate-400">Aadhaar</p>
                <p className="font-mono font-bold text-slate-800 mt-0.5">{selectedDealer.aadhaar || selectedDealer.aadhaar_number || 'N/A'}</p>
              </div>
              <div className="rounded-lg bg-slate-50 p-2.5 border border-slate-100">
                <p className="text-[10px] uppercase font-semibold text-slate-400">FSSAI Status</p>
                <span className={`inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold mt-0.5 ${
                  (selectedDealer.fssai_verification_status === 'VERIFIED') ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
                }`}>
                  {selectedDealer.fssai_verification_status || 'PENDING'}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3 rounded-xl bg-slate-50 p-3 border border-slate-100">
              <div>
                <p className="text-[10px] uppercase font-semibold text-slate-400">Dealer Credit Limit</p>
                <p className="font-bold text-slate-900 mt-0.5 text-sm">₹{parseFloat(selectedDealer.credit_limit || 0).toLocaleString('en-IN')}</p>
              </div>
              <div>
                <p className="text-[10px] uppercase font-semibold text-slate-400">Current Outstanding</p>
                <p className="font-bold text-rose-600 mt-0.5 text-sm">₹{parseFloat(selectedDealer.current_outstanding || 0).toLocaleString('en-IN')}</p>
              </div>
            </div>

            {/* Uploaded Verification Documents */}
            <div className="space-y-2">
              <p className="text-[11px] uppercase font-bold text-slate-700 tracking-wider">Uploaded KYC Documents</p>
              <div className="rounded-xl border border-slate-200 overflow-hidden divide-y divide-slate-100">
                {selectedDealer.fssai_certificate_url && (
                  <div className="p-2.5 flex items-center justify-between hover:bg-slate-50">
                    <div className="flex items-center gap-2">
                      <FileText className="h-4 w-4 text-emerald-600" />
                      <div>
                        <p className="font-semibold text-slate-800 text-xs">FSSAI License Certificate</p>
                        <p className="text-[10px] text-slate-500 font-mono">{selectedDealer.fssai_number || 'Official Registration'}</p>
                      </div>
                    </div>
                    <a
                      href={selectedDealer.fssai_certificate_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="inline-flex items-center gap-1 px-2.5 py-1 rounded bg-sky-50 text-sky-700 font-semibold hover:bg-sky-100 transition-colors"
                    >
                      <span>View</span>
                      <ExternalLink className="h-3 w-3" />
                    </a>
                  </div>
                )}

                {(selectedDealer.documents || []).length > 0 ? (
                  selectedDealer.documents.map((doc, idx) => (
                    <div key={idx} className="p-2.5 flex items-center justify-between hover:bg-slate-50">
                      <div className="flex items-center gap-2">
                        <FileText className="h-4 w-4 text-sky-600" />
                        <div>
                          <p className="font-semibold text-slate-800 text-xs">{doc.type_display || doc.document_type}</p>
                          <p className="text-[10px] text-slate-500 font-medium">Status: {doc.verification_status || 'Uploaded'}</p>
                        </div>
                      </div>
                      {doc.file_url ? (
                        <a
                          href={doc.file_url}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 px-2.5 py-1 rounded bg-sky-50 text-sky-700 font-semibold hover:bg-sky-100 transition-colors"
                        >
                          <span>View</span>
                          <ExternalLink className="h-3 w-3" />
                        </a>
                      ) : (
                        <span className="text-[10px] text-slate-400">On file</span>
                      )}
                    </div>
                  ))
                ) : (
                  !selectedDealer.fssai_certificate_url && (
                    <div className="p-3 text-center text-slate-400 text-[11px]">
                      No digital file attachments uploaded yet. Information verified through direct registration.
                    </div>
                  )
                )}
              </div>
            </div>

            {hasPermission('franchises', 'edit') && (
              <div className="border-t border-slate-100 pt-4 flex items-center justify-end space-x-3">
                {selectedDealer.status !== 'rejected' && (
                  <button
                    onClick={() => handleUpdateStatus(selectedDealer.id, 'rejected')}
                    className="inline-flex items-center space-x-1.5 rounded-lg border border-rose-200 bg-rose-50 px-3.5 py-2 text-xs font-semibold text-rose-700 hover:bg-rose-100"
                  >
                    <X className="h-4 w-4" />
                    <span>Reject Application</span>
                  </button>
                )}
                {selectedDealer.status !== 'approved' && (
                  <button
                    onClick={() => handleUpdateStatus(selectedDealer.id, 'approved')}
                    className="inline-flex items-center space-x-1.5 rounded-lg bg-emerald-600 px-3.5 py-2 text-xs font-semibold text-white hover:bg-emerald-500 shadow-sm"
                  >
                    <Check className="h-4 w-4" />
                    <span>Approve & Activate Dealer</span>
                  </button>
                )}
              </div>
            )}
          </div>
        </Modal>
      )}
    </div>
  );
}
