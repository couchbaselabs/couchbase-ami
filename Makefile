
EC2_HOME=./ec2-api-tools-1.4.4.2
EC2_PRIVATE_KEY=~/.ec2/pk-LNGJGIFNQUNA6GWNURZFDKGB6CLJ7M4W.pem
EC2_CERT=~/.ec2/cert-LNGJGIFNQUNA6GWNURZFDKGB6CLJ7M4W.pem
EC2_URL=https://ec2.us-east-1.amazonaws.com
SSH_KEY=steveyen-key
SSH_CMD=ssh -i ~/.ssh/$(SSH_KEY).pem ec2-user@$(HOST)

INSTANCE_TYPE=m1.xlarge

IMAGE_NAME=membase-1.7.2_BasicAmazonLinux64-201109

PKG_BASE=http://builds.hq.northscale.net/releases/1.7.1.1
PKG_NAME=membase-server-enterprise_x86_64_1.7.1.1.rpm

image-create: instance-launch instance-prep instance-install instance-cleanse instance-image-create

instance-launch:
	$(EC2_HOME)/bin/ec2-run-instances ami-7341831a \
      --block-device-mapping /dev/sdb=ephemeral0 \
      --block-device-mapping /dev/sdc=ephemeral1 \
      --block-device-mapping /dev/sdd=ephemeral2 \
      --block-device-mapping /dev/sde=ephemeral3 \
      --availability-zone us-east-1d \
      --instance-type $(INSTANCE_TYPE) \
      --instance-initiated-shutdown-behavior stop \
      --group couchbase \
      --key $(SSH_KEY)

instance-prep:
	$(SSH_CMD) -t sudo yum -y install openssl098e gdb emacs
	echo TODO: EBS volume attachment goes here

instance-install:
	$(SSH_CMD) wget -O $(PKG_NAME) $(PKG_BASE)/$(PKG_NAME)
	$(SSH_CMD) -t sudo rpm -i $(PKG_NAME)

instance-cleanse:
	$(SSH_CMD) rm -f /home/ec2-user/.bash_history /home/ec2-user/.ssh/authorized_keys

instance-image-create:
	$(EC2_HOME)/bin/ec2-create-image -n $(IMAGE_NAME) $(INSTANCE_ID)

