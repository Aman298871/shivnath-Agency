import React, { useState, useEffect } from 'react';
import { Target, UserPlus, Search, RefreshCw, Phone, Mail, Building, CheckCircle2, AlertCircle, MessageSquare, ArrowRightCircle } from 'lucide-react';
import apiClient from '../api/client';
import Modal from '../components/common/Modal';
import { useAuth } from '../context/AuthContext';

export default function LeadsFollowups() {
  const { hasPermission } = useAuth();
  const [leads, setLeads] = useState([]);
  const [stats, setStats] = useState({ total_leads: 0, new_leads: 0, converted_leads: 0 });
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('ALL');

  // Add Lead Modal State
  const [isAddLeadOpen, setIsAddLeadOpen] = useState(false);
  const [leadName, setLeadName] = useState('');
  const [leadPhone, setLeadPhone] = useState('');
  const [leadEmail, setLeadEmail] = useState('');
  const [businessName, setBusinessName] = useState('');
  const [leadSource, setLeadSource] = useState('DIRECT');
  const [notes, setNotes] = useState('');
  const [isSubmittingLead, setIsSubmittingLead] = useState(false);
  const [leadError, setLeadError] = useState('');

  // Activity / Followup Modal State
  const [selectedLead, setSelectedLead] = useState(null);
  const [activityNote, setActivityNote] = useState('');
  const [activityType, setActivityType] = useState('CALL');
  const [isLoggingActivity, setIsLoggingActivity] = useState(false);

  const fetchLeads = async () => {
    try {
      setIsLoading(true);
      const [leadsRes, statsRes] = await Promise.all([
        apiClient.get('/api/leads/').catch(() => ({ data: [] })),
        apiClient.get('/api/leads/stats/').catch(() => ({ data: {} })),
      ]);

      const lList = leadsRes.data?.leads || leadsRes.data?.results || (Array.isArray(leadsRes.data) ? leadsRes.data : []);
      setLeads(lList);
      setStats(statsRes.data?.stats || statsRes.data || { total_leads: lList.length });
    } catch (err) {
      console.warn('Leads fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchLeads();
  }, []);

  const handleAddLead = async (e) => {
    e.preventDefault();
    setIsSubmittingLead(true);
    setLeadError('');

    try {
      await apiClient.post('/api/leads/', {
        name: leadName.trim(),
        phone: leadPhone.trim(),
        email: leadEmail.trim() || undefined,
        business_name: businessName.trim() || undefined,
        source: leadSource,
        notes: notes.trim() || undefined,
      });

      setIsAddLeadOpen(false);
      setLeadName('');
      setLeadPhone('');
      setLeadEmail('');
      setBusinessName('');
      setNotes('');
      fetchLeads();
    } catch (err) {
      setLeadError(err.response?.data?.message || err.response?.data?.error || err.message || 'Failed to add lead');
    } finally {
      setIsSubmittingLead(false);
    }
  };

  const handleConvertLead = async (leadId) => {
    if (!window.confirm('Convert this lead into an active Customer account?')) return;
    try {
      await apiClient.post(`/api/leads/${leadId}/convert/`, {});
      alert('Lead successfully converted to an active Customer.');
      fetchLeads();
    } catch (err) {
      alert(err.response?.data?.message || err.response?.data?.error || err.message || 'Conversion failed');
    }
  };

  const handleLogActivity = async (e) => {
    e.preventDefault();
    if (!selectedLead || !activityNote) return;
    setIsLoggingActivity(true);

    try {
      await apiClient.post(`/api/leads/${selectedLead.id}/activities/`, {
        activity_type: activityType,
        notes: activityNote.trim(),
      });
      setSelectedLead(null);
      setActivityNote('');
      fetchLeads();
    } catch (err) {
      alert(err.response?.data?.message || err.message || 'Failed to log activity');
    } finally {
      setIsLoggingActivity(false);
    }
  };

  const filtered = leads.filter((l) => {
    if (statusFilter !== 'ALL' && (l.status || '').toUpperCase() !== statusFilter) {
      return false;
    }
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      l.name?.toLowerCase().includes(q) ||
      l.phone?.includes(q) ||
      l.business_name?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">
            CRM Leads & Follow-ups
          </h1>
          <p className="text-sm text-slate-500">
            Track inquiries, corporate event prospects, WhatsApp inquiries & customer conversion pipeline
          </p>
        </div>

        <div className="flex items-center space-x-2">
          {hasPermission('customers', 'create') && (
            <button
              onClick={() => setIsAddLeadOpen(true)}
              className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
            >
              <UserPlus className="h-4 w-4" />
              <span>Capture Lead</span>
            </button>
          )}

          <button
            onClick={fetchLeads}
            className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
          >
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {/* Metric Highlights */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <p className="text-xs font-bold text-slate-500 uppercase tracking-wider">Total Pipeline Leads</p>
          <p className="mt-2 text-2xl font-black text-slate-900">{leads.length}</p>
        </div>

        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <p className="text-xs font-bold text-slate-500 uppercase tracking-wider">New Uncontacted</p>
          <p className="mt-2 text-2xl font-black text-amber-600">
            {leads.filter((l) => (l.status || 'NEW').toUpperCase() === 'NEW').length}
          </p>
        </div>

        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
          <p className="text-xs font-bold text-slate-500 uppercase tracking-wider">Converted to Customers</p>
          <p className="mt-2 text-2xl font-black text-emerald-600">
            {leads.filter((l) => (l.status || '').toUpperCase() === 'CONVERTED').length}
          </p>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col sm:flex-row gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="relative flex-1">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search leads by name, phone or company..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
          />
        </div>

        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="rounded-lg border border-slate-200 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none font-semibold text-slate-700"
        >
          <option value="ALL">All Statuses</option>
          <option value="NEW">New Inquiries</option>
          <option value="CONTACTED">Contacted</option>
          <option value="QUALIFIED">Qualified</option>
          <option value="CONVERTED">Converted</option>
          <option value="LOST">Lost</option>
        </select>
      </div>

      {/* Leads Table */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Lead Name</th>
                <th className="pb-3">Phone / Contact</th>
                <th className="pb-3">Organization</th>
                <th className="pb-3">Source</th>
                <th className="pb-3">Status</th>
                <th className="pb-3">Captured</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="7" className="py-12 text-center text-slate-400">
                    No leads found matching criteria.
                  </td>
                </tr>
              ) : (
                filtered.map((l) => {
                  const status = (l.status || 'NEW').toUpperCase();
                  const isConverted = status === 'CONVERTED';

                  return (
                    <tr key={l.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="py-3.5 font-bold text-slate-900">{l.name}</td>
                      <td className="py-3.5 text-slate-600 font-mono">{l.phone || '—'}</td>
                      <td className="py-3.5 text-slate-700">{l.business_name || 'Individual'}</td>
                      <td className="py-3.5">
                        <span className="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-semibold bg-slate-100 text-slate-700">
                          {l.source || 'DIRECT'}
                        </span>
                      </td>
                      <td className="py-3.5">
                        <span className={`inline-flex items-center px-2 py-0.5 rounded text-[11px] font-semibold ${
                          status === 'CONVERTED'
                            ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                            : status === 'NEW'
                            ? 'bg-amber-50 text-amber-700 border border-amber-200'
                            : 'bg-sky-50 text-sky-700 border border-sky-200'
                        }`}>
                          {status}
                        </span>
                      </td>
                      <td className="py-3.5 text-slate-500">
                        {l.created_at ? new Date(l.created_at).toLocaleDateString() : 'Today'}
                      </td>
                      <td className="py-3.5 text-right space-x-1.5 whitespace-nowrap">
                        <button
                          onClick={() => setSelectedLead(l)}
                          className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200"
                        >
                          <MessageSquare className="h-3.5 w-3.5" />
                          <span>Activity</span>
                        </button>

                        {!isConverted && (
                          <button
                            onClick={() => handleConvertLead(l.id)}
                            className="inline-flex items-center space-x-1 rounded-md bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700 hover:bg-emerald-100 border border-emerald-200"
                            title="Convert to Active Customer"
                          >
                            <ArrowRightCircle className="h-3.5 w-3.5" />
                            <span>Convert</span>
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

      {/* CAPTURE LEAD MODAL */}
      {isAddLeadOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsAddLeadOpen(false)}
          title="Capture Inbound Sales Lead"
          maxWidth="max-w-md"
        >
          <form onSubmit={handleAddLead} className="space-y-4 text-xs">
            {leadError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-800 border border-rose-200">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{leadError}</span>
              </div>
            )}

            <div>
              <label className="block font-semibold text-slate-700">Contact / Person Name</label>
              <input
                type="text"
                required
                value={leadName}
                onChange={(e) => setLeadName(e.target.value)}
                placeholder="e.g. Rahul Sharma"
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Phone Number</label>
              <input
                type="text"
                required
                value={leadPhone}
                onChange={(e) => setLeadPhone(e.target.value)}
                placeholder="e.g. 9826199999"
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Organization / Business Name</label>
              <input
                type="text"
                value={businessName}
                onChange={(e) => setBusinessName(e.target.value)}
                placeholder="e.g. Grand Shagun Hotel"
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Lead Source</label>
              <select
                value={leadSource}
                onChange={(e) => setLeadSource(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              >
                <option value="DIRECT">Direct Sales Call / Inbound</option>
                <option value="WHATSAPP">WhatsApp Inquiry</option>
                <option value="CHATBOT">Website AI Chatbot</option>
                <option value="REFERRAL">Franchise Dealer Referral</option>
                <option value="EXHIBITION">Event / Exhibition</option>
              </select>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Requirement Notes</label>
              <textarea
                rows="2"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="e.g. Requires 50 cartons 200ml bottles weekly"
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsAddLeadOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmittingLead}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSubmittingLead ? 'Capturing...' : 'Save Lead'}
              </button>
            </div>
          </form>
        </Modal>
      )}

      {/* LOG ACTIVITY MODAL */}
      {selectedLead && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedLead(null)}
          title={`Log Follow-up — ${selectedLead.name}`}
          maxWidth="max-w-md"
        >
          <form onSubmit={handleLogActivity} className="space-y-4 text-xs">
            <div>
              <label className="block font-semibold text-slate-700">Interaction Type</label>
              <select
                value={activityType}
                onChange={(e) => setActivityType(e.target.value)}
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              >
                <option value="CALL">Phone Call</option>
                <option value="WHATSAPP">WhatsApp Chat</option>
                <option value="MEETING">In-Person Meeting</option>
                <option value="EMAIL">Email Follow-up</option>
                <option value="SAMPLE">Sample Delivered</option>
              </select>
            </div>

            <div>
              <label className="block font-semibold text-slate-700">Notes & Next Actions</label>
              <textarea
                rows="3"
                required
                value={activityNote}
                onChange={(e) => setActivityNote(e.target.value)}
                placeholder="e.g. Spoke to procurement manager. Sent rate card, follow up next Tuesday."
                className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
              />
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setSelectedLead(null)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isLoggingActivity}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isLoggingActivity ? 'Recording...' : 'Save Activity'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
