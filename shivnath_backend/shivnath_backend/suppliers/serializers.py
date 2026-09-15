from rest_framework import serializers

from .models import Supplier


class SupplierSerializer(serializers.ModelSerializer):

    class Meta:
        model = Supplier

        fields = [
            "id",
            "name",
            "contact",
            "phone",
            "email",
            "category",
            "gst",
            "city",
            "status",
            "created_at",
            "updated_at",
        ]

    def validate_phone(self, value):

        qs = Supplier.objects.filter(
            phone=value
        )

        if self.instance:
            qs = qs.exclude(id=self.instance.id)

        if qs.exists():
            raise serializers.ValidationError(
                "Phone number already exists."
            )

        return value

    def validate_name(self, value):

        if not value.strip():
            raise serializers.ValidationError(
                "Supplier name is required."
            )

        return value.strip()

    def validate(self, attrs):

        attrs["gst"] = attrs.get(
            "gst",
            "",
        ).upper()

        return attrs