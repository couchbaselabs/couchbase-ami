
EC2_HOME        = ./ec2-api-tools-1.4.4.2
EC2_PRIVATE_KEY = ~/.ec2/couchbase_aws-marketplace/pk-RPGT6DCSVXNK5QWMHAACI3KUHN5ILKOX.pem
EC2_CERT        = ~/.ec2/couchbase_aws-marketplace/cert-RPGT6DCSVXNK5QWMHAACI3KUHN5ILKOX.pem
EC2_ZONE        = us-east-1c
EC2_URL         = https://ec2.us-east-1.amazonaws.com

# The seed AMI is Basic Amazon Linux 64-bit 2011.09
#AMI_ID          = ami-28670341
AMI_ID          = ami-7341831a

INSTANCE_TYPE = m1.xlarge
INSTANCE_HOST = `grep INSTANCE instance-describe.out | grep running | cut -f 4`
INSTANCE_ID   = `grep INSTANCE instance-describe.out | grep running | cut -f 2`

# old amazon ami id
OLD_INSTANCE_ID 	    = i-e67a0883

SSH_KEY = ronnie-ec2-key
SSH_CMD = ssh -i ~/.ssh/$(SSH_KEY).pem ec2-user@$(INSTANCE_HOST)

VERSION = 3.0.1
IMAGE_NAME = couchbase_server_community_x86_64_${VERSION}
IMAGE_DESC = pre-installed Couchbase Server ${VERSION}, Community Edition, 64bit
#IMAGE_NAME = couchbase_server_enterprise_x86_64_${VERSION}
#IMAGE_DESC = pre-installed Couchbase Server ${VERSION}, Enterprise Edition, 64bit

#PKG_BASE = http://builder.hq.couchbase.com/get
PKG_BASE = http://packages.couchbase.com/releases/${VERSION}
PKG_NAME = couchbase-server-community-${VERSION}-centos6.x86_64.rpm
#PKG_NAME = couchbase-server-enterprise_centos6_x86_64_${VERSION}-1209-rel.rpm
PKG_KIND = couchbase
CLI_NAME = couchbase-cli

SECURITY_GROUP = couchbase

VOLUME_ID = `grep VOLUME volume-describe.out | cut -f 2`
VOLUME_GB = 80

SNAPSHOT_ID = `grep SNAPSHOT snapshot-describe.out | cut -f 2`

step0: \
    instance-launch

step1: \
    instance-prep

step2: \
    instance-prep-pkg

step3: \
    volume-create \
    volume-attach \
    volume-mkfs \
    snapshot-create \
    volume-mount

step4: \
    instance-cleanse \
    instance-image-create

describe-image:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    $(EC2_HOME)/bin/ec2-describe-images -o amazon --filter "image-type=kernel"

generate-key:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    $(EC2_HOME)/bin/ec2-create-keypair ${SSH_KEY} > ${SSH_KEY}
	cp ${SSH_KEY} ~/.ssh/

instance-launch:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-run-instances $(AMI_ID) \
      --block-device-mapping /dev/sdb=ephemeral0 \
      --block-device-mapping /dev/sdc=ephemeral1 \
      --block-device-mapping /dev/sdd=ephemeral2 \
      --block-device-mapping /dev/sde=ephemeral3 \
      --availability-zone $(EC2_ZONE) \
      --instance-type $(INSTANCE_TYPE) \
      --instance-initiated-shutdown-behavior stop \
      --group $(SECURITY_GROUP) \
      --key $(SSH_KEY) > instance-describe.out
	sleep 30
	$(MAKE) instance-describe
	cat instance-describe.out

instance-describe:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-describe-instances $(INSTANCE_ID) > instance-describe.out
	cat instance-describe.out

instance-clean:
	$(SSH_CMD) yum clean all

instance-update:
	 $(SSH_CMD) -t sudo yum update

instance-prep:
	scp -i ~/.ssh/$(SSH_KEY).pem prep \
      ec2-user@$(INSTANCE_HOST):/home/ec2-user/prep
	$(SSH_CMD) -t sudo /home/ec2-user/prep

instance-prep-pkg:
	$(SSH_CMD) wget -O $(PKG_NAME) $(PKG_BASE)/$(PKG_NAME)
	sed -e s,@@PKG_NAME@@,$(PKG_NAME),g README.txt.tmpl | \
      sed -e s,@@PKG_KIND@@,$(PKG_KIND),g | \
      sed -e s,@@CLI_NAME@@,$(CLI_NAME),g > README.txt.out
	sed -e s,@@PKG_NAME@@,$(PKG_NAME),g config-pkg.tmpl | \
      sed -e s,@@PKG_KIND@@,$(PKG_KIND),g | \
      sed -e s,@@CLI_NAME@@,$(CLI_NAME),g > config-pkg.out
	chmod a+x config-pkg.out
	scp -i ~/.ssh/$(SSH_KEY).pem README.txt.out \
      ec2-user@$(INSTANCE_HOST):/home/ec2-user/README.txt
	scp -i ~/.ssh/$(SSH_KEY).pem config-pkg.out \
      ec2-user@$(INSTANCE_HOST):/home/ec2-user/config-pkg
	$(SSH_CMD) -t sudo mkdir -p /var/lib/cloud/data/scripts
	$(SSH_CMD) -t sudo cp /home/ec2-user/config-pkg /var/lib/cloud/data/scripts/config-pkg
	$(SSH_CMD) -t sudo chown root:root /var/lib/cloud/data/scripts/config-pkg
	$(SSH_CMD) -t sudo rpm --install $(PKG_NAME)

instance-cleanse:
	$(SSH_CMD) -t sudo rm -f \
      /home/ec2-user/.bash_history \
      /home/ec2-user/.ssh/authorized_keys \
      /home/ec2-user/*.tmp \
      /home/ec2-user/*~ \
      /root/.bash_history \
      /root/.ssh/authorized_keys \
      /root/*.tmp \
      /root/*~

list-amis:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
    $(EC2_HOME)/bin/ec2-stop-instances ${INSTANCE_ID}

instance-image-create:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-image \
      --name "$(IMAGE_NAME)" \
      --description "$(IMAGE_DESC)" \
      $(INSTANCE_ID)

instance-image-recreate:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-image $(OLD_INSTANCE_ID) \
      --name "$(IMAGE_NAME)" \
      --description "$(IMAGE_DESC)"

instance-stop:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
    $(EC2_HOME)/bin/ec2-stop-instances $(INSTANCE_ID)

volume-create:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-volume \
      --availability-zone $(EC2_ZONE) \
      --size $(VOLUME_GB) > volume-describe.out

volume-create-from-snapshot:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-volume \
      --availability-zone $(EC2_ZONE) \
      --size $(VOLUME_GB) \
      --snapshot $(SNAPSHOT_ID) > volume-describe.out

volume-describe:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-describe-volumes $(VOLUME_ID)

volume-attach:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-attach-volume $(VOLUME_ID) \
      --instance $(INSTANCE_ID) \
      --device /dev/sdh
	sleep 20

volume-mkfs:
	$(SSH_CMD) -t sudo mkfs.ext3 /dev/sdh

volume-mount:
	$(SSH_CMD) -t sudo mkdir -p /mnt
	$(SSH_CMD) -t sudo mkdir -m 000 /mnt/ebs
	$(SSH_CMD) -t "echo /dev/sdh /mnt/ebs ext3 noatime 0 0 | sudo tee -a /etc/fstab"
	$(SSH_CMD) -t sudo mount -a

snapshot-create:
	EC2_HOME=$(EC2_HOME) \
    EC2_PRIVATE_KEY=$(EC2_PRIVATE_KEY) \
    EC2_CERT=$(EC2_CERT) \
    EC2_URL=$(EC2_URL) \
      $(EC2_HOME)/bin/ec2-create-snapshot $(VOLUME_ID) \
      --description empty-ext3-$(VOLUME_GB)gb > snapshot-describe.out

clean:
	rm -f *.out

