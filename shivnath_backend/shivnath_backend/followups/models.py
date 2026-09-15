from django.db import models
from django.contrib.auth.models import User

from leads.models import Lead


class FollowUp(models.Model):

    TYPE_CHOICES = [
        ("Call", "Call"),
        ("WhatsApp", "WhatsApp"),
        ("Meeting", "Meeting"),
    ]

    STATUS_CHOICES = [
        ("Pending", "Pending"),
        ("Completed", "Completed"),
    ]

    lead = models.ForeignKey(
        Lead,
        on_delete=models.CASCADE,
        related_name="followups",
    )

    followup_datetime = models.DateTimeField()

    followup_type = models.CharField(
        max_length=20,
        choices=TYPE_CHOICES,
        default="Call",
    )

    note = models.TextField(
        blank=True,
    )

    status = models.CharField(
        max_length=20,
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

    completed_at = models.DateTimeField(
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