import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Package, Truck, AlertCircle, ArrowRight, X, Clock } from 'lucide-react';
import Modal from '../common/Modal';

export const NewOrderAlertModal = ({ order, isOpen, onClose, onOpenOrder }) => {
  const navigate = useNavigate();
  if (!isOpen || !order) return null;

  const orderNum = order.order_id || order.id || order.order_code || 'NEW';
  const customerName = order.customer_name || order.customer || 'Customer';
  const totalAmount = order.total_amount || order.amount || 0;
  const items = Array.isArray(order.items) ? order.items : [];
  const fulfillmentType = order.fulfillment_type || order.fulfillment || 'Shivnath Agency (Central Fulfillment)';

  const handleAction = () => {
    onClose();
    if (onOpenOrder) {
      onOpenOrder(order);
    } else {
      navigate('/orders');
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="🚨 New Customer Order Awaiting Fulfillment!"
      size="md"
    >
      <div className="space-y-4">
        <div className="flex items-center justify-between rounded-xl bg-amber-50 border border-amber-200 p-3.5">
          <div className="flex items-center space-x-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-amber-500 text-white shadow-sm">
              <Package className="h-5 w-5" />
            </div>
            <div>
              <p className="text-sm font-bold text-slate-900">Order #{orderNum}</p>
              <p className="text-xs text-slate-600">{customerName} • {fulfillmentType}</p>
            </div>
          </div>
          <div className="text-right">
            <span className="text-base font-extrabold text-sky-700">₹{Number(totalAmount).toFixed(2)}</span>
            <span className="block text-[10px] font-semibold uppercase text-amber-700 bg-amber-100/80 px-2 py-0.5 rounded-full mt-0.5">
              Action Required
            </span>
          </div>
        </div>

        {items.length > 0 && (
          <div className="rounded-xl border border-slate-100 bg-slate-50/70 p-3">
            <p className="text-[11px] font-bold uppercase tracking-wider text-slate-500 mb-2">Order Items ({items.length})</p>
            <div className="max-h-36 overflow-y-auto space-y-1.5 pr-1">
              {items.map((item, idx) => (
                <div key={idx} className="flex justify-between items-center text-xs bg-white p-2 rounded-lg border border-slate-200/60 shadow-2xs">
                  <span className="font-medium text-slate-800">{item.product_name || item.name || 'Water Bottle'}</span>
                  <span className="text-slate-600 font-semibold">{item.quantity} units</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex items-center text-xs text-slate-500 space-x-1.5">
          <Clock className="h-3.5 w-3.5 text-slate-400" />
          <span>Received at {new Date(order.created_at || Date.now()).toLocaleTimeString()}</span>
        </div>

        <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-100">
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-50"
          >
            Dismiss
          </button>
          <button
            type="button"
            onClick={handleAction}
            className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-4 py-2 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
          >
            <span>Open & Fulfill Order</span>
            <ArrowRight className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>
    </Modal>
  );
};

export const NewStockRequestAlertModal = ({ request, isOpen, onClose, onOpenRequest }) => {
  const navigate = useNavigate();
  if (!isOpen || !request) return null;

  const reqNum = request.id || request.request_id || request.code || 'REQ';
  const franchiseName = request.franchise_name || request.franchise || request.dealer_name || 'Authorized Franchise';
  const totalUnits = request.total_units || request.quantity || request.requested_quantity || 'Bulk';
  const items = Array.isArray(request.items) ? request.items : [];

  const handleAction = () => {
    onClose();
    if (onOpenRequest) {
      onOpenRequest(request);
    } else {
      navigate('/plant-stock');
    }
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="📦 Franchise Stock Request Received!"
      size="md"
    >
      <div className="space-y-4">
        <div className="flex items-center justify-between rounded-xl bg-sky-50 border border-sky-200 p-3.5">
          <div className="flex items-center space-x-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-sky-600 text-white shadow-sm">
              <Truck className="h-5 w-5" />
            </div>
            <div>
              <p className="text-sm font-bold text-slate-900">{franchiseName}</p>
              <p className="text-xs text-slate-600">Request #{reqNum} • Central Stock Allocation</p>
            </div>
          </div>
          <div className="text-right">
            <span className="text-sm font-extrabold text-sky-800">{totalUnits} units</span>
            <span className="block text-[10px] font-semibold uppercase text-sky-700 bg-sky-100 px-2 py-0.5 rounded-full mt-0.5">
              Needs Review
            </span>
          </div>
        </div>

        {items.length > 0 && (
          <div className="rounded-xl border border-slate-100 bg-slate-50/70 p-3">
            <p className="text-[11px] font-bold uppercase tracking-wider text-slate-500 mb-2">Requested Inventory</p>
            <div className="max-h-36 overflow-y-auto space-y-1.5 pr-1">
              {items.map((item, idx) => (
                <div key={idx} className="flex justify-between items-center text-xs bg-white p-2 rounded-lg border border-slate-200/60 shadow-2xs">
                  <span className="font-medium text-slate-800">{item.product_name || item.name || 'Stock Item'}</span>
                  <span className="text-sky-700 font-bold">{item.quantity} boxes / units</span>
                </div>
              ))}
            </div>
          </div>
        )}

        <div className="flex items-center text-xs text-slate-500 space-x-1.5">
          <AlertCircle className="h-3.5 w-3.5 text-sky-500" />
          <span>Central inventory will be allocated upon approval and dispatch.</span>
        </div>

        <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-100">
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg border border-slate-200 px-4 py-2 text-xs font-semibold text-slate-700 hover:bg-slate-50"
          >
            Dismiss
          </button>
          <button
            type="button"
            onClick={handleAction}
            className="inline-flex items-center space-x-1.5 rounded-lg bg-sky-600 px-4 py-2 text-xs font-semibold text-white shadow-sm hover:bg-sky-500 transition-colors"
          >
            <span>Review & Allocate Stock</span>
            <ArrowRight className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>
    </Modal>
  );
};
