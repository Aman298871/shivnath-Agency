import React from 'react';

export default function StatusBadge({ status, type = 'order' }) {
  const norm = (status || '').toUpperCase();

  const orderStyles = {
    PENDING: 'bg-amber-50 text-amber-700 border-amber-200',
    PLANT_APPROVAL: 'bg-sky-50 text-sky-700 border-sky-200',
    PROCESSING: 'bg-sky-50 text-sky-700 border-sky-200',
    PREPARING: 'bg-blue-50 text-blue-700 border-blue-200',
    MANUFACTURING: 'bg-indigo-50 text-indigo-700 border-indigo-200',
    ON_HOLD: 'bg-amber-100 text-amber-800 border-amber-300 font-bold',
    CONFIRMED: 'bg-indigo-50 text-indigo-700 border-indigo-200',
    DISPATCHED: 'bg-purple-50 text-purple-700 border-purple-200',
    OUT_FOR_DELIVERY: 'bg-blue-50 text-blue-700 border-blue-200',
    DELIVERED: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    CANCELLED: 'bg-rose-50 text-rose-700 border-rose-200',
    PAID: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    PARTIAL: 'bg-amber-50 text-amber-700 border-amber-200',
    UNPAID: 'bg-rose-50 text-rose-700 border-rose-200',
    APPROVED: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    REJECTED: 'bg-rose-100 text-rose-800 border-rose-300 font-bold',
    ACTIVE: 'bg-emerald-50 text-emerald-700 border-emerald-200',
    INACTIVE: 'bg-slate-100 text-slate-600 border-slate-200',
  };

  const style = orderStyles[norm] || 'bg-slate-50 text-slate-700 border-slate-200';

  return (
    <span className={`inline-flex items-center rounded-md border px-2.5 py-0.5 text-xs font-semibold ${style}`}>
      {status ? status.replace(/_/g, ' ') : 'N/A'}
    </span>
  );
}
