#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM clusterlite/base:2.0.0

ADD files /

RUN chmod a+rx /run-*.sh && /install-chronograf.sh

# 8888: chronograf clients
