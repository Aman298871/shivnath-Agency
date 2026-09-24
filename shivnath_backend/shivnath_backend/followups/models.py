from django.db import models
from django.contrib.auth.models import User

from leads.models import Lead


class FollowUp(models.Model):

    TYPE_CHOICES = [
        ("Call", "Call"),
        ("Phone Call", "Phone Call"),
        ("WhatsApp", "WhatsApp"),
        ("Email", "Email"),
        ("Meeting", "Meeting"),
        ("Site Visit", "Site Visit"),
        ("Other", "Other"),
    ]

    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Completed", "Completed"),
        ("Rescheduled", "Rescheduled"),
        ("Cancelled", "Cancelled"),
        ("Missed", "Missed"),
    ]

    lead = models.ForeignKey(
        Lead,
        on_delete=models.CASCADE,
        related_name="followups",
    )

    followup_datetime = models.DateTimeField()

    followup_type = models.CharField(
        max_length=30,
        choices=TYPE_CHOICES,
        default="Phone Call",
    )

    note = models.TextField(
        blank=True,
    )

    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default="Pending",
    )

    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_followups",
    )

    updated_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="updated_followups",
    )

    completed_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    completed_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="completed_followups",
    )

    outcome_notes = models.TextField(
        blank=True,
        default="",
    )

    original_followup_datetime = models.DateTimeField(
        null=True,
        blank=True,
    )

    next_followup_date = models.DateTimeField(
        null=True,
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    class Meta:
        ordering = [
            "followup_datetime",
        ]

        indexes = [
            models.Index(
                fields=["followup_datetime"],
            ),
            models.Index(
                fields=["status"],
            ),
        ]

    def __str__(self):
        return (
            f"{self.lead.name} "
            f"- {self.followup_datetime}"
        )


class FollowUpAuditLog(models.Model):
    """
    Authoritative audit history for all follow-up actions:
    CREATED, RESCHEDULED, COMPLETED, REOPENED, CANCELLED.
    Preserves historical outcomes, dates, who performed the action, and notes.
    """
    ACTION_CHOICES = [
        ('CREATED', 'Created'),
        ('RESCHEDULED', 'Rescheduled'),
        ('COMPLETED', 'Completed'),
        ('REOPENED', 'Reopened'),
        ('CANCELLED', 'Cancelled'),
    ]

    followup = models.ForeignKey(
        FollowUp,
        on_delete=models.CASCADE,
        related_name='audit_logs',
    )
    lead = models.ForeignKey(
        Lead,
        on_delete=models.CASCADE,
        related_name='followup_audit_logs',
        null=True,
        blank=True,
    )
    action = models.CharField(
        max_length=20,
        choices=ACTION_CHOICES,
        db_index=True,
    )
    previous_status = models.CharField(max_length=30, blank=True, default='')
    new_status = models.CharField(max_length=30, blank=True, default='')
    previous_datetime = models.DateTimeField(null=True, blank=True)
    new_datetime = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True, default='')
    performed_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='followup_actions',
    )
    performed_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-performed_at']
        indexes = [
            models.Index(fields=['followup', 'action']),
            models.Index(fields=['performed_at']),
        ]

    def __str__(self):
        return f"[{self.action}] FollowUp #{self.followup_id} by {self.performed_by} at {self.performed_at}"