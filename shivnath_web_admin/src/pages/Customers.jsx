import React, { useState, useEffect } from 'react';
import { Users, Search, Phone, Mail, MapPin, Eye, RefreshCw, ShoppingBag } from 'lucide-react';
import apiClient from '../api/client';
import Modal from '../components/common/Modal';

export default function Customers() {
  const [customers, setCustomers] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedCustomer, setSelectedCustomer] = useState(null);

  const fetchCustomers = async () => {
    try {
      setIsLoading(true);
      const res = await apiClient.get('/api/auth/admin/customers/');
      const results = res.data?.results || res.data?.customers || (Array.isArray(res.data) ? res.data : []);
      setCustomers(results);
    } catch (err) {
      console.warn('Customers fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleOpenCustomer = async (cust) => {
    try {
      const detailRes = await apiClient.get(`/api/auth/admin/customers/${cust.id}/`);
      if (detailRes.data?.customer) {
        setSelectedCustomer(detailRes.data.customer);
      } else {
        setSelectedCustomer(cust);
      }
    } catch (err) {
      setSelectedCustomer(cust);
    }
  };

  useEffect(() => {
    fetchCustomers();
  }, []);

  const filtered = customers.filter((c) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      c.name?.toLowerCase().includes(q) ||
      c.phone?.includes(q) ||
      c.email?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Page Title */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Customer CRM</h1>
          <p className="text-sm text-slate-500">Retail customer profiles, spending history, and delivery records</p>
        </div>

        <button
          onClick={fetchCustomers}
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
            placeholder="Search customer by name, mobile number, or email..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>
      </div>

      {/* Customer Directory Table */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Customer Name</th>
                <th className="pb-3">Mobile Phone</th>
                <th className="pb-3">Email</th>
                <th className="pb-3">Registered Date</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="5" className="py-12 text-center text-slate-400">
                    No customer records found.
                  </td>
                </tr>
              ) : (
                filtered.map((c) => (
                  <tr key={c.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 font-bold text-slate-900 flex items-center space-x-2">
                      <div className="flex h-7 w-7 items-center justify-center rounded-full bg-sky-100 text-sky-700 font-bold text-[10px]">
                        {c.name ? c.name.slice(0, 2).toUpperCase() : 'CU'}
                      </div>
                      <span>{c.name || 'Anonymous Customer'}</span>
                    </td>
                    <td className="py-3.5 text-slate-700 font-mono">{c.phone || c.mobile || 'N/A'}</td>
                    <td className="py-3.5 text-slate-500">{c.email || 'N/A'}</td>
                    <td className="py-3.5 text-slate-500">
                      {c.date_joined ? new Date(c.date_joined).toLocaleDateString() : 'Active'}
                    </td>
                    <td className="py-3.5 text-right">
                      <button
                        onClick={() => handleOpenCustomer(c)}
                        className="inline-flex items-center space-x-1 rounded-md bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-200 transition-colors cursor-pointer"
                      >
                        <Eye className="h-3.5 w-3.5" />
                        <span>Profile</span>
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Customer Detail Modal */}
      {selectedCustomer && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedCustomer(null)}
          title="Customer Profile & History"
        >
          <div className="space-y-4 text-xs">
            <div className="flex items-center space-x-3 rounded-xl bg-slate-50 p-4 border border-slate-100">
              <div className="flex h-12 w-12 items-center justify-center rounded-full bg-sky-600 text-white font-bold text-base">
                {selectedCustomer.name ? selectedCustomer.name.slice(0, 2).toUpperCase() : 'CU'}
              </div>
              <div>
                <h3 className="font-bold text-slate-900 text-sm">{selectedCustomer.name}</h3>
                <p className="text-slate-500">Customer ID: #{selectedCustomer.id}</p>
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex items-center space-x-2 text-slate-600">
                <Phone className="h-4 w-4 text-slate-400" />
                <span>{selectedCustomer.phone || selectedCustomer.mobile || 'No phone recorded'}</span>
              </div>
              <div className="flex items-center space-x-2 text-slate-600">
                <Mail className="h-4 w-4 text-slate-400" />
                <span>{selectedCustomer.email || 'No email recorded'}</span>
              </div>
              <div className="flex items-center space-x-2 text-slate-600">
                <MapPin className="h-4 w-4 text-slate-400" />
                <span>{selectedCustomer.address || 'Address on file with order deliveries'}</span>
              </div>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
