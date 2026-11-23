import React, { useState, useEffect } from 'react';
import { BarChart3, Download, Calendar, DollarSign, Package, TrendingUp, RefreshCw } from 'lucide-react';
import apiClient from '../api/client';
import MetricCard from '../components/common/MetricCard';

export default function Reports() {
  const [reportData, setReportData] = useState({
    totalSales: 0,
    totalOrders: 0,
    estimatedCOGS: 0,
    grossProfit: 0,
  });
  const [dateRange, setDateRange] = useState('30d');
  const [isLoading, setIsLoading] = useState(true);

  const fetchReports = async () => {
    try {
      setIsLoading(true);
      const [ordersRes, statsRes] = await Promise.all([
        apiClient.get('/api/orders/'),
        apiClient.get('/api/auth/admin/dashboard-stats/'),
      ]);

      const orders = ordersRes.data?.orders || ordersRes.data?.results || (Array.isArray(ordersRes.data) ? ordersRes.data : []);
      const ordStats = statsRes.data?.stats?.orders || statsRes.data?.orders || {};

      const total = ordStats.total_order_value || ordStats.total_value || orders.reduce((sum, o) => sum + parseFloat(o.total_amount || 0), 0);
      const totalCount = ordStats.total_orders || ordStats.total || orders.length;
      const cogs = total * 0.45; // Estimated direct production + bottle packaging costs (45%)
      const profit = total - cogs;

      setReportData({
        totalSales: total,
        totalOrders: totalCount,
        estimatedCOGS: cogs,
        grossProfit: profit,
      });
    } catch (err) {
      console.warn('Reports fetch error:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchReports();
  }, [dateRange]);

  const handleExportCSV = async () => {
    try {
      // Fetch authoritative CSV from backend export endpoint
      try {
        const response = await apiClient.get('/api/reports/export/orders/', {
          responseType: 'blob',
        });
        const blob = new Blob([response.data], { type: 'text/csv;charset=utf-8;' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.setAttribute('href', url);
        link.setAttribute('download', `orders_report_${new Date().toISOString().slice(0, 10)}.csv`);
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        return;
      } catch (backendCsvErr) {
        console.warn('Backend CSV endpoint fallback to JSON serialization', backendCsvErr);
      }

      const ordersRes = await apiClient.get('/api/orders/');
      const orders = ordersRes.data?.orders || ordersRes.data?.results || (Array.isArray(ordersRes.data) ? ordersRes.data : []);

      const headers = ['Order ID', 'Customer/Franchise', 'Status', 'Total Amount (INR)', 'Payment Status', 'Created At'];
      const rows = orders.map((o) => [
        o.id,
        `"${o.customer_name || o.franchise_name || 'Customer'}"`,
        o.order_status,
        parseFloat(o.total_amount || 0).toFixed(2),
        o.payment_status || 'UNPAID',
        o.created_at || '',
      ]);

      const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map((e) => e.join(','))].join('\n');
      const encodedUri = encodeURI(csvContent);
      const link = document.createElement('a');
      link.setAttribute('href', encodedUri);
      link.setAttribute('download', `water_wala_sales_report_${new Date().toISOString().slice(0, 10)}.csv`);
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    } catch (err) {
      alert('Failed to generate export file.');
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-slate-900">Reports & Daily P&L</h1>
          <p className="text-sm text-slate-500">
            Financial analytics, gross profitability, and exportable business spreadsheets
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={handleExportCSV}
            className="inline-flex items-center space-x-2 rounded-lg bg-emerald-600 px-3.5 py-2 text-xs font-semibold text-white shadow-sm hover:bg-emerald-500 transition-colors"
          >
            <Download className="h-4 w-4" />
            <span>Export CSV</span>
          </button>
          <button
            onClick={fetchReports}
            className="inline-flex items-center space-x-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-700 shadow-sm hover:bg-slate-50"
          >
            <RefreshCw className={`h-4 w-4 ${isLoading ? 'animate-spin text-sky-600' : 'text-slate-500'}`} />
          </button>
        </div>
      </div>

      {/* Date Range Selector */}
      <div className="rounded-xl border border-slate-200 bg-white p-4 shadow-sm flex items-center justify-between">
        <span className="text-xs font-bold text-slate-700 uppercase tracking-wider">Report Window</span>
        <div className="flex space-x-2">
          {['7d', '30d', '90d', '1y'].map((range) => (
            <button
              key={range}
              onClick={() => setDateRange(range)}
              className={`rounded-lg px-3 py-1.5 text-xs font-semibold ${
                dateRange === range
                  ? 'bg-sky-600 text-white'
                  : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
              }`}
            >
              {range.toUpperCase()}
            </button>
          ))}
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <MetricCard
          title="Gross Sales Revenue"
          value={`₹${reportData.totalSales.toLocaleString('en-IN', { minimumFractionDigits: 2 })}`}
          subtitle="Total recorded order value"
          icon={DollarSign}
          color="sky"
        />
        <MetricCard
          title="Total Orders Processed"
          value={reportData.totalOrders.toString()}
          subtitle="Orders within window"
          icon={Package}
          color="indigo"
        />
        <MetricCard
          title="Estimated COGS"
          value={`₹${reportData.estimatedCOGS.toLocaleString('en-IN', { minimumFractionDigits: 2 })}`}
          subtitle="Raw materials & packaging"
          icon={TrendingUp}
          color="amber"
        />
        <MetricCard
          title="Net Gross Margin"
          value={`₹${reportData.grossProfit.toLocaleString('en-IN', { minimumFractionDigits: 2 })}`}
          subtitle="Operating contribution"
          icon={BarChart3}
          color="emerald"
        />
      </div>
    </div>
  );
}
