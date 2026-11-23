import React, { useState } from 'react';
import { Menu, Bell, Wifi, WifiOff, RefreshCw, LogOut, Shield } from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { useRealTime } from '../../context/RealTimeContext';

export default function Header({ onMenuToggle }) {
  const { user, logout } = useAuth();
  const { syncStatus, unreadCount, notifications, markAllAsRead, clearNotifications, reconnect } = useRealTime();
  const [showNotifications, setShowNotifications] = useState(false);

  return (
    <header className="flex h-16 items-center justify-between border-b border-slate-200 bg-white px-4 sm:px-6 lg:px-8">
      {/* Mobile Toggle & Status */}
      <div className="flex items-center space-x-3">
        <button
          onClick={onMenuToggle}
          className="rounded-lg p-2 text-slate-600 hover:bg-slate-100 hover:text-slate-900 lg:hidden"
        >
          <Menu className="h-6 w-6" />
        </button>

        {/* Real-time synchronization indicator */}
        <div className="flex items-center space-x-2 text-xs font-medium">
          {syncStatus === 'live' && (
            <span className="inline-flex items-center rounded-full bg-emerald-50 px-2.5 py-1 text-emerald-700 border border-emerald-200">
              <span className="mr-1.5 h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
              Live Sync Active
            </span>
          )}
          {syncStatus === 'connecting' && (
            <span className="inline-flex items-center rounded-full bg-amber-50 px-2.5 py-1 text-amber-700 border border-amber-200">
              <RefreshCw className="mr-1.5 h-3 w-3 animate-spin text-amber-600" />
              Connecting...
            </span>
          )}
          {syncStatus === 'reconnecting' && (
            <span className="inline-flex items-center rounded-full bg-amber-50 px-2.5 py-1 text-amber-700 border border-amber-200">
              <RefreshCw className="mr-1.5 h-3 w-3 animate-spin text-amber-600" />
              Reconnecting...
            </span>
          )}
          {syncStatus === 'offline' && (
            <button
              onClick={reconnect}
              className="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-1 text-slate-600 hover:bg-slate-200 border border-slate-300"
            >
              <WifiOff className="mr-1.5 h-3 w-3 text-slate-500" />
              Offline (Click to retry)
            </button>
          )}
        </div>
      </div>

      {/* Right controls */}
      <div className="flex items-center space-x-4">
        {/* Notification Bell */}
        <div className="relative">
          <button
            onClick={() => {
              setShowNotifications((prev) => !prev);
              if (!showNotifications && unreadCount > 0) {
                markAllAsRead();
              }
            }}
            className="relative rounded-lg p-2 text-slate-500 hover:bg-slate-100 hover:text-slate-700"
          >
            <Bell className="h-5 w-5" />
            {unreadCount > 0 && (
              <span className="absolute right-1 top-1 flex h-4 w-4 items-center justify-center rounded-full bg-rose-500 text-[10px] font-bold text-white shadow">
                {unreadCount > 9 ? '9+' : unreadCount}
              </span>
            )}
          </button>

          {/* Notifications Dropdown */}
          {showNotifications && (
            <div className="absolute right-0 mt-2 w-80 sm:w-96 rounded-xl border border-slate-200 bg-white p-4 shadow-xl z-50">
              <div className="flex items-center justify-between border-b border-slate-100 pb-2 mb-3">
                <h4 className="text-sm font-bold text-slate-800">Real-Time Event Stream</h4>
                {notifications.length > 0 && (
                  <button
                    onClick={clearNotifications}
                    className="text-xs text-sky-600 hover:underline"
                  >
                    Clear All
                  </button>
                )}
              </div>

                <div className="max-h-80 overflow-y-auto space-y-2">
                  {notifications.length === 0 ? (
                    <p className="py-6 text-center text-xs text-slate-400">
                      No notifications yet. Live stream is listening.
                    </p>
                  ) : (
                    notifications.map((n) => (
                      <div
                        key={n.id}
                        className={`rounded-lg p-2.5 text-xs border transition-colors ${
                          n.read ? 'bg-slate-50 border-slate-100' : 'bg-sky-50/70 border-sky-100 font-medium'
                        }`}
                      >
                        <div className="flex items-center justify-between text-slate-500 mb-1">
                          <span className="font-semibold text-slate-800 uppercase text-[11px] tracking-wide">
                            {n.title || n.type}
                          </span>
                          <span className="text-[10px] text-slate-400">
                            {n.timestamp ? (n.timestamp.includes('T') || n.timestamp.includes(' ') ? new Date(n.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : n.timestamp) : ''}
                          </span>
                        </div>
                        <p className="text-slate-600 text-xs">
                          {n.message || JSON.stringify(n.payload || {})}
                        </p>
                      </div>
                    ))
                  )}
                </div>
            </div>
          )}
        </div>

        {/* User Badging & Logout */}
        <div className="flex items-center space-x-3 border-l border-slate-200 pl-4">
          <div className="hidden sm:block text-right">
            <p className="text-sm font-semibold text-slate-800">{user?.name || user?.username}</p>
            <p className="text-xs text-slate-500 capitalize">{user?.role?.replace('_', ' ')}</p>
          </div>
          <button
            onClick={logout}
            title="Log Out"
            className="flex items-center space-x-1 rounded-lg px-2.5 py-1.5 text-xs font-semibold text-rose-600 hover:bg-rose-50 border border-rose-200 transition-colors"
          >
            <LogOut className="h-4 w-4" />
            <span className="hidden sm:inline">Logout</span>
          </button>
        </div>
      </div>
    </header>
  );
}
