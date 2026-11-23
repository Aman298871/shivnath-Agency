import React from 'react';
import { NavLink } from 'react-router-dom';
import {
  LayoutDashboard,
  ShoppingCart,
  Users,
  Store,
  Package,
  Layers,
  Receipt,
  ShieldCheck,
  BarChart3,
  Activity,
  Droplets,
  X,
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';

export default function Sidebar({ isOpen, onClose }) {
  const { user, hasPermission } = useAuth();

  const navItems = [
    { name: 'Dashboard', path: '/', icon: LayoutDashboard, module: 'dashboard', action: 'view' },
    { name: 'Live Orders', path: '/orders', icon: ShoppingCart, module: 'orders', action: 'view' },
    { name: 'Customers CRM', path: '/customers', icon: Users, module: 'customers', action: 'view' },
    { name: 'Franchise Dealers', path: '/franchises', icon: Store, module: 'franchises', action: 'view' },
    { name: 'Master Catalog', path: '/products', icon: Package, module: 'products', action: 'view' },
    { name: 'MOQ & Delivery Slabs', path: '/moq-delivery', icon: Layers, module: 'moq', action: 'view' },
    { name: 'Billing & Payments', path: '/billing', icon: Receipt, module: 'billing', action: 'view' },
    { name: 'Employees & RBAC', path: '/employees', icon: ShieldCheck, module: 'employees', action: 'view' },
    { name: 'Reports & P&L', path: '/reports', icon: BarChart3, module: 'reports', action: 'view' },
    { name: 'System Activity Logs', path: '/activity', icon: Activity, module: 'activity', action: 'view' },
  ];

  const visibleNav = navItems.filter((item) => {
    if (item.module === 'dashboard') return true;
    return hasPermission(item.module, item.action);
  });

  return (
    <aside
      className={`fixed inset-y-0 left-0 z-50 w-64 bg-slate-900 text-white flex flex-col transition-transform duration-200 ease-in-out lg:static lg:translate-x-0 ${
        isOpen ? 'translate-x-0' : '-translate-x-0 -translate-x-full'
      }`}
    >
      {/* Brand Header */}
      <div className="flex h-16 items-center justify-between px-6 bg-slate-950 border-b border-slate-800">
        <div className="flex items-center space-x-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-sky-500 shadow-lg shadow-sky-500/30">
            <Droplets className="h-6 w-6 text-white" />
          </div>
          <div>
            <span className="text-base font-bold tracking-tight text-white block leading-none">
              WATER WALA
            </span>
            <span className="text-[11px] font-medium text-sky-400 uppercase tracking-wider block mt-1">
              Shivnath Agency
            </span>
          </div>
        </div>
        <button
          onClick={onClose}
          className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-800 hover:text-white lg:hidden"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Navigation Links */}
      <nav className="flex-1 space-y-1 overflow-y-auto px-3 py-4">
        {visibleNav.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.path}
              to={item.path}
              end={item.path === '/'}
              onClick={onClose}
              className={({ isActive }) =>
                `flex items-center space-x-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-sky-600 text-white shadow-sm'
                    : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                }`
              }
            >
              <Icon className="h-5 w-5 shrink-0 opacity-80" />
              <span>{item.name}</span>
            </NavLink>
          );
        })}
      </nav>

      {/* User Status Footer */}
      <div className="border-t border-slate-800 bg-slate-950/60 p-4">
        <div className="flex items-center space-x-3">
          <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-slate-700 text-xs font-bold text-white">
            {user?.name ? user.name.slice(0, 2).toUpperCase() : 'AD'}
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-semibold text-white">
              {user?.name || user?.username}
            </p>
            <p className="truncate text-xs font-medium text-slate-400 capitalize">
              {user?.role?.replace('_', ' ') || 'Administrator'}
            </p>
          </div>
        </div>
      </div>
    </aside>
  );
}
