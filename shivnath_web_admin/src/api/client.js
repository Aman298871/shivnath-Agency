import axios from 'axios';

const getApiBaseUrl = () => {
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL;
  }
  // When running locally in browser (localhost:3000), target the local Django server on port 8000
  if (typeof window !== 'undefined' && (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1')) {
    return 'http://127.0.0.1:8000';
  }
  return 'https://api.shivnathagencies.com';
};

const API_BASE_URL = getApiBaseUrl();

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 30000,
});

// Request interceptor to attach JWT token
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('ww_access_token');
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor with automatic token refresh
let isRefreshing = false;
let failedQueue = [];

const processQueue = (error, token = null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token);
    }
  });
  failedQueue = [];
};

apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      if (
        originalRequest.url?.includes('/api/token/') ||
        originalRequest.url?.includes('/api/auth/login/') ||
        originalRequest.url?.includes('/login')
      ) {
        return Promise.reject(error);
      }

      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then((token) => {
            originalRequest.headers['Authorization'] = `Bearer ${token}`;
            return apiClient(originalRequest);
          })
          .catch((err) => Promise.reject(err));
      }

      originalRequest._retry = true;
      isRefreshing = true;

      const refreshToken = localStorage.getItem('ww_refresh_token');
      if (!refreshToken) {
        localStorage.removeItem('ww_access_token');
        localStorage.removeItem('ww_refresh_token');
        localStorage.removeItem('ww_user_profile');
        window.dispatchEvent(new Event('auth:logout'));
        return Promise.reject(error);
      }

      try {
        let refreshResponse;
        try {
          refreshResponse = await axios.post(`${API_BASE_URL}/api/auth/refresh/`, {
            refresh: refreshToken,
          });
        } catch (rfErr) {
          if (rfErr.response?.status === 404) {
            refreshResponse = await axios.post(`${API_BASE_URL}/api/token/refresh/`, {
              refresh: refreshToken,
            });
          } else {
            throw rfErr;
          }
        }

        const newAccessToken = refreshResponse.data.access;
        localStorage.setItem('ww_access_token', newAccessToken);
        apiClient.defaults.headers.common['Authorization'] = `Bearer ${newAccessToken}`;

        processQueue(null, newAccessToken);
        isRefreshing = false;

        originalRequest.headers['Authorization'] = `Bearer ${newAccessToken}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        processQueue(refreshError, null);
        isRefreshing = false;
        localStorage.removeItem('ww_access_token');
        localStorage.removeItem('ww_refresh_token');
        localStorage.removeItem('ww_user_profile');
        window.dispatchEvent(new Event('auth:logout'));
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  }
);

export default apiClient;
export { API_BASE_URL };
