import React, { useState, useEffect } from 'react';
import { Activity, Search, Filter, RefreshCw, User, Clock, Shield } from 'lucide-react';
import apiClient from '../api/client';
import { useRealTime } from '../context/RealTimeContext';

export default function AuditLogs() {
  const [logs, setLogs] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [actionFilter, setActionFilter] = useState('');
  const { subscribe } = useRealTime();

  const fetchLogs = async () => {
    try {
      setIsLoading(true);
      let url = '/api/accounts/audit-logs/?page_size=50';
      if (search) url += `&search=${encodeURIComponent(search)}`;
      if (actionFilter) url += `&action=${encodeURIComponent(actionFilter)}`;

      const res = await apiClient.get(url);
      setLogs(res.data?.results || res.data?.logs || []);
    } catch (err) {
      console.warn('Audit logs fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchLogs();

    // Auto-refresh when any system event occurs
    const unsub = subscribe('*', () => fetchLogs());
    return () => unsub();
  }, [search, actionFilter, subscribe]);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">System Activity Center & Audit Trail</h1>
          <p className="text-sm text-slate-500">
            Immutable chronological record of administrative actions, state transitions, and security events
          </p>
        </div>

        <button
          onClick={fetchLogs}
          className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
        >
          <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
          <span>Refresh Feed</span>
        </button>
      </div>

      {/* Filter Toolbar */}
      <div className="flex flex-col sm:flex-row items-center gap-3 rounded-xl border border-slate-200 bg-white p-4 shadow-sm">
        <div className="relative flex-1 w-full">
          <Search className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search audit trail by actor, action, or resource ID..."
            className="w-full rounded-lg border border-slate-200 pl-9 pr-3 py-2 text-xs focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
          />
        </div>

        <div className="w-full sm:w-auto">
          <select
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
            className="w-full sm:w-52 rounded-lg border border-slate-200 px-3 py-2 text-xs text-slate-700 focus:border-sky-500 focus:outline-none"
          >
            <option value="">All Actions</option>
            <option value="CREATE_ADMIN">CREATE_ADMIN</option>
            <option value="UPDATE_ADMIN">UPDATE_ADMIN</option>
            <option value="DISABLE_ADMIN">DISABLE_ADMIN</option>
            <option value="UPDATE_ORDER_STATUS">UPDATE_ORDER_STATUS</option>
            <option value="VERIFY_PAYMENT">VERIFY_PAYMENT</option>
          </select>
        </div>
      </div>

      {/* Audit Log Chronological Feed */}
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-100 text-slate-500 font-semibold uppercase">
              <tr>
                <th className="pb-3">Timestamp</th>
                <th className="pb-3">Actor / Admin</th>
                <th className="pb-3">Action</th>
                <th className="pb-3">Target Resource</th>
                <th className="pb-3">Payload Changes</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {logs.length === 0 ? (
                <tr>
                  <td colSpan="5" className="py-12 text-center text-slate-400">
                    No audit records matching query.
                  </td>
                </tr>
              ) : (
                logs.map((log) => (
                  <tr key={log.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="py-3.5 text-slate-500 font-mono text-[11px] whitespace-nowrap">
                      {log.created_at}
                    </td>
                    <td className="py-3.5 font-bold text-slate-900 flex items-center space-x-2">
                      <div className="flex h-6 w-6 items-center justify-center rounded-full bg-slate-100 text-slate-600 font-bold text-[10px]">
                        <User className="h-3 w-3" />
                      </div>
                      <span>{log.actor_name || log.actor_email || 'System'}</span>
                    </td>
                    <td className="py-3.5">
                      <span className="rounded bg-sky-50 px-2 py-0.5 font-mono font-semibold text-sky-700 border border-sky-200 text-[11px]">
                        {log.action}
                      </span>
                    </td>
                    <td className="py-3.5 font-medium text-slate-700">
                      {log.resource_type} #{log.resource_id}
                    </td>
                    <td className="py-3.5 max-w-xs">
                      <pre className="truncate font-mono text-[10px] text-slate-500 bg-slate-50 p-1 rounded border border-slate-100">
                        {JSON.stringify(log.changes || {})}
                      </pre>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
