"""
Orders Service Layer.
Exposes authoritative order lifecycle operations:
- reservation (FEFO company & dealer)
- status transitions (OrderStatusHistory logging)
- dispatch, delivery (revenue recognition milestone), and cancellation.
"""

from decimal import Decimal
from django.db import transaction
from django.utils import timezone
from .models import Order, OrderStatusHistory
from inventory.services import (
    reserve_order_stock_fefo_atomic,
    dispatch_order_atomic as _inv_dispatch_order_atomic,
    deliver_order_atomic as _inv_deliver_order_atomic,
    cancel_order_atomic as _inv_cancel_order_atomic,
)


@transaction.atomic
def transition_order_status(order, new_status, actor=None, notes=''):
    """
    Authoritative state machine transition for Order.
    Logs immutable OrderStatusHistory and executes appropriate inventory actions.
    """
    old_status = order.status
    order._actor = actor
    order._status_notes = notes

    if new_status == 'dispatch':
        return _inv_dispatch_order_atomic(order, actor=actor)
    elif new_status == 'delivered':
        return _inv_deliver_order_atomic(order, actor=actor)
    elif new_status == 'cancelled':
        return _inv_cancel_order_atomic(order, actor=actor)
    else:
        order.status = new_status
        order.save()
        return order


def dispatch_order_atomic(order, actor=None, notes=''):
    order._actor = actor
    order._status_notes = notes or 'Order dispatched with batch consumption'
    return _inv_dispatch_order_atomic(order, actor=actor)


def deliver_order_atomic(order, actor=None, notes=''):
    order._actor = actor
    order._status_notes = notes or 'Order delivered and revenue recognized'
    return _inv_deliver_order_atomic(order, actor=actor)


def cancel_order_atomic(order, actor=None, notes=''):
    order._actor = actor
    order._status_notes = notes or 'Order cancelled and stock released'
    return _inv_cancel_order_atomic(order, actor=actor)
