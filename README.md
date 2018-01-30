# Demo of instance store volume encryption with KMS managed keys

## Notes
Ideally you'd have one policy with something like `${aws:userid}` as the parameter path, but unfortunately the parameter store does not allow that as a valid name, so I've had to make one role, policy, IAM profile per instance in order to not have one instance being able to retrieve anothers encryption keys.
Terraform makes that a bit easier.

Code is hacky and intended only as a proof of concept, you might want to use not-default KMS, not use UUIDs as the encryption key, etc.