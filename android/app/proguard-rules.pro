# flutter_stripe referencia sus clases de push provisioning (integración con
# Google Wallet) aunque el proyecto no incluye esa dependencia opcional.
# Sin estas reglas, R8 falla en minifyReleaseWithR8 al no poder resolverlas.
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
