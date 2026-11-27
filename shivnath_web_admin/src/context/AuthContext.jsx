import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import apiClient from '../api/client';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(() => {
    const saved = localStorage.getItem('ww_user_profile');
    try {
      return saved ? JSON.parse(saved) : null;
    } catch {
      return null;
    }
  });
  const [token, setToken] = useState(() => localStorage.getItem('ww_access_token'));
  const [isLoading, setIsLoading] = useState(true);

  const fetchCurrentUser = useCallback(async () => {
    try {
      const res = await apiClient.get('/api/accounts/me/');
      const u = res.data?.user || (res.data?.id ? res.data : null);
      if (u) {
        setUser(u);
        localStorage.setItem('ww_user_profile', JSON.stringify(u));
        return u;
      }
    } catch (err) {
      console.warn('Failed to fetch current user profile:', err);
    }
    return null;
  }, []);

  useEffect(() => {
    const initAuth = async () => {
      const currentToken = localStorage.getItem('ww_access_token');
      if (currentToken) {
        await fetchCurrentUser();
      }
      setIsLoading(false);
    };

    initAuth();

    const handleAuthLogout = () => {
      setUser(null);
      setToken(null);
    };

    window.addEventListener('auth:logout', handleAuthLogout);
    return () => window.removeEventListener('auth:logout', handleAuthLogout);
  }, [fetchCurrentUser]);

  const login = async (usernameOrEmail, password) => {
    // 1. Authenticate with backend login endpoint (/api/auth/login/ with fallback to /api/token/)
    let loginRes;
    try {
      loginRes = await apiClient.post('/api/auth/login/', {
        email: usernameOrEmail,
        username: usernameOrEmail,
        password: password,
      });
    } catch (err) {
      if (err.response?.status === 404) {
        loginRes = await apiClient.post('/api/token/', {
          username: usernameOrEmail,
          password: password,
        });
      } else {
        throw err;
      }
    }

    const { access, refresh } = loginRes.data;
    if (!access) {
      throw new Error('Authentication succeeded but access token was not returned.');
    }

    localStorage.setItem('ww_access_token', access);
    if (refresh) {
      localStorage.setItem('ww_refresh_token', refresh);
    }
    setToken(access);

    // 2. Obtain full authenticated user profile with permissions
    let userData = null;
    try {
      const profileRes = await apiClient.get('/api/accounts/me/', {
        headers: { Authorization: `Bearer ${access}` },
      });
      userData = profileRes.data?.user || (profileRes.data?.id ? profileRes.data : null);
    } catch (profileErr) {
      console.warn('Could not fetch /api/accounts/me/, falling back to login response user data', profileErr);
    }

    if (!userData && loginRes.data?.user) {
      userData = loginRes.data.user;
    }

    if (!userData) {
      throw new Error('Failed to retrieve user profile.');
    }

    // Strict validation: Only administrative or operational roles can enter the Web Admin Portal
    const allowedRoles = ['admin', 'super_admin', 'stock_manager', 'sales_executive'];
    if (!allowedRoles.includes(userData.role)) {
      localStorage.removeItem('ww_access_token');
      localStorage.removeItem('ww_refresh_token');
      localStorage.removeItem('ww_user_profile');
      throw new Error(`Unauthorized: Role '${userData.role}' is not permitted to access the Web Admin Portal.`);
    }

    if (userData.status === 'inactive') {
      localStorage.removeItem('ww_access_token');
      localStorage.removeItem('ww_refresh_token');
      localStorage.removeItem('ww_user_profile');
      throw new Error('Your administrative account is deactivated or suspended.');
    }

    setUser(userData);
    localStorage.setItem('ww_user_profile', JSON.stringify(userData));
    return userData;
  };

  const logout = () => {
    localStorage.removeItem('ww_access_token');
    localStorage.removeItem('ww_refresh_token');
    localStorage.removeItem('ww_user_profile');
    setUser(null);
    setToken(null);
  };

  /**
   * Evaluates action- and module-level granular RBAC.
   * Super Admins inherit wildcard permission (*).
   */
  const hasPermission = useCallback((module, action = 'view') => {
    if (!user) return false;
    if (user.role === 'super_admin') return true;

    // Check base roles
    if (user.role === 'stock_manager' && ['inventory', 'products'].includes(module)) return true;
    if (user.role === 'sales_executive' && ['customers', 'leads', 'orders'].includes(module) && action === 'view') return true;

    const perms = new Set(user.admin_permissions || []);
    if (perms.has('*') || perms.has('all')) return true;
    const checkModule = (mod) => {
      if (perms.has(mod) || perms.has(`${mod}:*`)) return true;
      if (perms.has(`${mod}:${action}`)) return true;
      return false;
    };

    if (checkModule(module)) return true;
    // Check aliases
    if (module === 'dealers' && checkModule('franchises')) return true;
    if (module === 'franchises' && checkModule('dealers')) return true;
    if (module === 'customers' && checkModule('leads')) return true;
    if (module === 'leads' && checkModule('customers')) return true;
    if (module === 'moq' && (checkModule('orders') || checkModule('products'))) return true;

    return false;
  }, [user]);

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isAuthenticated: !!user && !!token,
        isLoading,
        login,
        logout,
        hasPermission,
        refreshProfile: fetchCurrentUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
