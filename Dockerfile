FROM ubuntu:xenial

ENV EXTRACT_PARAMS=stepsize=6:shakiness=10:accuracy=15
ENV STAB_PARAMS=zoom=1:smoothing=30,unsharp=5:5:0.8:3:3:0.4
ENV X264_CRF=18
ENV X264_PRESET=slow
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -yq software-properties-common python-software-properties s3cmd python-pip && \
    add-apt-repository ppa:mc3man/ffmpeg-test && \
    apt-get update && \
    apt-get install -yq ffmpeg-static && \
    pip install awscli && \
    apt-get remove -y python-pip

ADD stabilize.sh /opt/

CMD ["/bin/bash", "/opt/stabilize.sh"]
