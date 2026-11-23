import React, { useState, useEffect } from 'react';
import { ShieldCheck, UserPlus, Search, UserX, Check, RefreshCw, AlertCircle, Key } from 'lucide-react';
import Modal from '../components/common/Modal';
import apiClient from '../api/client';
import { useAuth } from '../context/AuthContext';
import StatusBadge from '../components/common/StatusBadge';

export default function Employees() {
  const { user: currentUser } = useAuth();
  const [admins, setAdmins] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);

  // Form State
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    name: '',
    phone: '',
    password: '',
    confirm_password: '',
    role: 'admin',
    admin_permissions: ['orders:view', 'orders:edit', 'inventory:view'],
  });
  const [formError, setFormError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const availablePermissions = [
    { id: 'orders:view', label: 'View Orders' },
    { id: 'orders:edit', label: 'Dispatch & Update Orders' },
    { id: 'customers:view', label: 'View Customers' },
    { id: 'franchises:view', label: 'View Franchises' },
    { id: 'franchises:approve', label: 'Approve & Reject KYC' },
    { id: 'products:view', label: 'View Catalog' },
    { id: 'inventory:view', label: 'View Inventory' },
    { id: 'inventory:edit', label: 'Adjust Inventory' },
    { id: 'moq:view', label: 'View MOQ Rules' },
    { id: 'moq:edit', label: 'Edit MOQ & Delivery Slabs' },
    { id: 'billing:view', label: 'View Invoices' },
    { id: 'billing:edit', label: 'Record & Verify Payments' },
    { id: 'reports:view', label: 'View Analytics & P&L' },
    { id: 'reports:export', label: 'Export Reports to CSV' },
    { id: 'activity:view', label: 'View Audit Logs' },
  ];

  const fetchAdmins = async () => {
    try {
      setIsLoading(true);
      const res = await apiClient.get('/api/accounts/super-admin/admins/');
      setAdmins(res.data?.admins || []);
    } catch (err) {
      console.warn('Employees fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchAdmins();
  }, []);

  const handleTogglePermission = (permId) => {
    setFormData((prev) => {
      const current = new Set(prev.admin_permissions);
      if (current.has(permId)) {
        current.delete(permId);
      } else {
        current.add(permId);
      }
      return { ...prev, admin_permissions: Array.from(current) };
    });
  };

  const handleCreateAdmin = async (e) => {
    e.preventDefault();
    setFormError('');

    if (formData.password !== formData.confirm_password) {
      setFormError('Passwords do not match.');
      return;
    }

    setIsSubmitting(true);
    try {
      await apiClient.post('/api/accounts/super-admin/admins/', formData);
      setIsAddModalOpen(false);
      setFormData({
        username: '',
        email: '',
        name: '',
        phone: '',
        password: '',
        confirm_password: '',
        role: 'admin',
        admin_permissions: ['orders:view', 'orders:edit', 'inventory:view'],
      });
      fetchAdmins();
    } catch (err) {
      const msg = err.response?.data?.error || err.message || 'Failed to create employee account.';
      setFormError(msg);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeactivate = async (adminId) => {
    if (!confirm('Are you sure you want to deactivate this administrative employee? Access will be immediately revoked.')) return;
    try {
      await apiClient.delete(`/api/accounts/super-admin/admins/${adminId}/`);
      fetchAdmins();
    } catch (err) {
      alert(err.response?.data?.error || err.message || 'Failed to deactivate account.');
    }
  };

  const filtered = admins.filter((a) => {
    if (!search) return true;
    const q = search.toLowerCase();
    return (
      a.name?.toLowerCase().includes(q) ||
      a.email?.toLowerCase().includes(q) ||
      a.username?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Employees & RBAC Access</h1>
          <p className="text-sm text-slate-500">
            Granular action- and module-level permission control for administrative staff
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={() => setIsAddModalOpen(true)}
            className="inline-flex items-center space-x-2 rounded-lg bg-sky-600 px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
          >
            <UserPlus className="h-4 w-4" />
            <span>Add Staff Member</span>
          </button>
          <button
            onClick={fetchAdmins}
            className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
          >
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
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
            placeholder="Search employees by name, username, or email..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>
      </div>

      {/* Employees Table */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Employee Name</th>
                <th className="pb-3">Email / Username</th>
                <th className="pb-3">Assigned Role</th>
                <th className="pb-3">Granular Permissions</th>
                <th className="pb-3">Account Status</th>
                <th className="pb-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filtered.length === 0 ? (
                <tr>
                  <td colSpan="6" className="py-12 text-center text-slate-400">
                    No administrative employees found.
                  </td>
                </tr>
              ) : (
                filtered.map((adm) => (
                  <tr key={adm.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 font-bold text-slate-900">{adm.name || adm.username}</td>
                    <td className="py-3.5 text-slate-600 font-mono">{adm.email}</td>
                    <td className="py-3.5 font-semibold text-slate-800 capitalize">
                      {adm.role?.replace('_', ' ')}
                    </td>
                    <td className="py-3.5 text-slate-500">
                      <div className="flex flex-wrap gap-1 max-w-xs">
                        {(adm.admin_permissions || []).length === 0 ? (
                          <span className="text-slate-400">Default Role Access</span>
                        ) : (
                          adm.admin_permissions.slice(0, 3).map((p, idx) => (
                            <span key={idx} className="rounded bg-slate-100 px-1.5 py-0.5 text-[10px] font-mono">
                              {p}
                            </span>
                          ))
                        )}
                        {(adm.admin_permissions || []).length > 3 && (
                          <span className="text-[10px] text-slate-400">+{adm.admin_permissions.length - 3} more</span>
                        )}
                      </div>
                    </td>
                    <td className="py-3.5">
                      <StatusBadge status={adm.is_active ? 'ACTIVE' : 'INACTIVE'} />
                    </td>
                    <td className="py-3.5 text-right">
                      {adm.id !== currentUser?.id && adm.is_active && (
                        <button
                          onClick={() => handleDeactivate(adm.id)}
                          className="inline-flex items-center space-x-1 rounded-md bg-rose-50 px-2.5 py-1 text-xs font-semibold text-rose-700 hover:bg-rose-100"
                        >
                          <UserX className="h-3.5 w-3.5" />
                          <span>Deactivate</span>
                        </button>
                      )}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Employee Modal */}
      {isAddModalOpen && (
        <Modal
          isOpen={true}
          onClose={() => setIsAddModalOpen(false)}
          title="Create Operational Administrative Employee"
          maxWidth="max-w-2xl"
        >
          <form onSubmit={handleCreateAdmin} className="space-y-4 text-xs">
            {formError && (
              <div className="flex items-center space-x-2 rounded-lg bg-rose-50 p-3 text-rose-700 border border-rose-200">
                <AlertCircle className="h-4 w-4" />
                <span>{formError}</span>
              </div>
            )}

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Full Name</label>
                <input
                  type="text"
                  required
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="Ramesh Patel"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
              <div>
                <label className="block font-semibold text-slate-700">Official Email</label>
                <input
                  type="email"
                  required
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  placeholder="ramesh@waterwala.in"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Mobile Phone</label>
                <input
                  type="text"
                  value={formData.phone}
                  onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                  placeholder="9876543210"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
              <div>
                <label className="block font-semibold text-slate-700">Role Baseline</label>
                <select
                  value={formData.role}
                  onChange={(e) => setFormData({ ...formData, role: e.target.value })}
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                >
                  <option value="admin">Operational Admin</option>
                  <option value="sales_executive">Sales Executive</option>
                  <option value="stock_manager">Stock & Inventory Manager</option>
                </select>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-semibold text-slate-700">Initial Password</label>
                <input
                  type="password"
                  required
                  value={formData.password}
                  onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                  placeholder="••••••••••••"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
              <div>
                <label className="block font-semibold text-slate-700">Confirm Password</label>
                <input
                  type="password"
                  required
                  value={formData.confirm_password}
                  onChange={(e) => setFormData({ ...formData, confirm_password: e.target.value })}
                  placeholder="••••••••••••"
                  className="mt-1 block w-full rounded-lg border border-slate-300 px-3 py-2 text-xs focus:border-sky-500 focus:outline-none"
                />
              </div>
            </div>

            {/* Granular Permissions Checkboxes */}
            <div>
              <label className="block font-semibold text-slate-700 mb-2">Granular Action Privileges</label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 rounded-xl bg-slate-50 p-3 border border-slate-200 max-h-48 overflow-y-auto">
                {availablePermissions.map((perm) => (
                  <label key={perm.id} className="flex items-center space-x-2 text-[11px] text-slate-700 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={formData.admin_permissions.includes(perm.id)}
                      onChange={() => handleTogglePermission(perm.id)}
                      className="rounded border-slate-300 text-sky-600 focus:ring-sky-500"
                    />
                    <span>{perm.label}</span>
                  </label>
                ))}
              </div>
            </div>

            <div className="flex justify-end space-x-2 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setIsAddModalOpen(false)}
                className="rounded-lg border border-slate-200 px-3 py-2 font-semibold text-slate-600 hover:bg-slate-50"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className="rounded-lg bg-sky-600 px-4 py-2 font-semibold text-white hover:bg-sky-500 disabled:opacity-50"
              >
                {isSubmitting ? 'Creating...' : 'Create Employee'}
              </button>
            </div>
          </form>
        </Modal>
      )}
    </div>
  );
}
