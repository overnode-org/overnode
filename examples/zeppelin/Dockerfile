#
# License: https://github.com/webintrinsics/clusterlite/blob/master/LICENSE
#

FROM clusterlite/base-jvm:2.0.0

ADD files /

RUN chmod a+rx /run-*.sh && /install-zeppelin.sh

# 8090: zeppelin clients
# 4040: spark driver webui
