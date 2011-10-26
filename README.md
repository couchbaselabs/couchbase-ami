Scripts to create couchbase amazon ec2 AMI's.

# Prerequisites

You'll need....

* java (for the amazon ec2 API tools)
* JAVA_HOME environment variable properly pointed at your java.

## Get the scripts

    git clone git@github.com:couchbaselabs/couchbase-ami.git
    cd couchbase-ami

## Setup credentials

    mkdir -p ~/.ec2/couchbase_aws-marketplace

Get the pk/cert for the marketplace-related AWS account.  They'll need to live at...

    ~/.ec2/couchbase_aws-marketplace/pk-RPGT6DCSVXNK5QWMHAACI3KUHN5ILKOX.pem
    ~/.ec2/couchbase_aws-marketplace/cert-RPGT6DCSVXNK5QWMHAACI3KUHN5ILKOX.pem

Get your ssh key so you can login into the EC2 instances.  These
usually will live in the ~/.ssh directory on your computer.  For example, mine is at...

    ~/.ssh/steveyen-key2

# Building the AMI...

First, clean up from previous attempts...

    make clean

Then, use step 0, which should launch an new EC2 instance.

    make SSH_KEY=steveyen-key2 image-create-step0

If that takes longer than usual (because EC2 cloud is impacted), then repeat the following command untill you finally see some ec2-xxxxxx.compute-1.amazonaws.com addresses in the output...

    make SSH_KEY=steveyen-key2 instance-describe

You'll want to see output lines that look like...

    INSTANCE	i-936991f0	ami-7341831a	ec2-107-22-35-176.compute-1.amazonaws.com	ip-10-93-70-157.ec2.internal	running	steveyen-key2	0		m1.xlarge	2011-10-26T22:59:43+0000	us-east-1c	aki-825ea7eb			monitoring-disabled	107.22.35.176	10.93.70.157			ebs					paravirtual	xen		sg-dddbcdb4	default

Then, go to the next step...

    make SSH_KEY=steveyen-key2 image-create-step1

Then, go to the next step...

    make SSH_KEY=steveyen-key2 image-create-step2

You should now have an AMI that's AWS / ISV Marketplace ready.
