import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import { RealTimeProvider } from './context/RealTimeContext';

import AdminLayout from './components/layout/AdminLayout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Orders from './pages/Orders';
import Customers from './pages/Customers';
import Franchises from './pages/Franchises';
import Products from './pages/Products';
import MoqDelivery from './pages/MoqDelivery';
import Billing from './pages/Billing';
import Employees from './pages/Employees';
import Reports from './pages/Reports';
import AuditLogs from './pages/AuditLogs';
import { ShieldAlert } from 'lucide-react';

const ProtectedRoute = ({ children, module, action = 'view' }) => {
  const { isAuthenticated, isLoading, hasPermission } = useAuth();

  if (isLoading) {
    return (
      <div className="flex h-screen items-center justify-center bg-slate-50">
        <div className="flex flex-col items-center space-y-3">
          <div className="h-10 w-10 animate-spin rounded-full border-4 border-sky-600 border-t-transparent" />
          <p className="text-xs font-semibold uppercase tracking-wider text-slate-500">
            Validating Security Credentials...
          </p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if (module && !hasPermission(module, action)) {
    return (
      <div className="flex flex-col items-center justify-center p-12 text-center">
        <div className="flex h-16 w-16 items-center justify-center rounded-2xl bg-rose-50 text-rose-600 border border-rose-200 mb-4">
          <ShieldAlert className="h-8 w-8" />
        </div>
        <h2 className="text-lg font-bold text-slate-900">Access Restricted</h2>
        <p className="mt-1 text-xs text-slate-500 max-w-sm">
          Your administrative account does not possess the granular privilege ({module}:{action}) required to access this module.
        </p>
      </div>
    );
  }

  return children;
};

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <RealTimeProvider>
          <Routes>
            <Route path="/login" element={<Login />} />

            <Route
              path="/"
              element={
                <ProtectedRoute>
                  <AdminLayout />
                </ProtectedRoute>
              }
            >
              <Route index element={<Dashboard />} />
              <Route path="orders" element={<ProtectedRoute module="orders"><Orders /></ProtectedRoute>} />
              <Route path="customers" element={<ProtectedRoute module="customers"><Customers /></ProtectedRoute>} />
              <Route path="franchises" element={<ProtectedRoute module="dealers"><Franchises /></ProtectedRoute>} />
              <Route path="products" element={<ProtectedRoute module="products"><Products /></ProtectedRoute>} />
              <Route path="moq-delivery" element={<ProtectedRoute module="moq"><MoqDelivery /></ProtectedRoute>} />
              <Route path="billing" element={<ProtectedRoute module="billing"><Billing /></ProtectedRoute>} />
              <Route path="employees" element={<ProtectedRoute module="employees" action="manage"><Employees /></ProtectedRoute>} />
              <Route path="reports" element={<ProtectedRoute module="reports"><Reports /></ProtectedRoute>} />
              <Route path="activity" element={<ProtectedRoute module="activity"><AuditLogs /></ProtectedRoute>} />
            </Route>

            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </RealTimeProvider>
      </AuthProvider>
    </BrowserRouter>
  );
}
