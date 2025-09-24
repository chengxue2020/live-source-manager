#!/bin/bash
# ���ô���ʱ�˳�
set -e

# ���� Python ʹ�� UTF-8 ����
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export PYTHONIOENCODING=utf-8

# ���뻷��������ʹ��Ĭ��ֵ��
UPDATE_CRON="${UPDATE_CRON:-0 12 * * *}"
TEST_TIMEOUT="${TEST_TIMEOUT:-10}"
CONCURRENT_THREADS="${CONCURRENT_THREADS:-50}"
OUTPUT_FILENAME="${OUTPUT_FILENAME:-live.m3u}"

# ���/config/config.ini�����ڣ���ʹ��Ĭ������
if [ ! -f /config/config.ini ]; then
    echo "����: /config/config.ini �����ڣ�ʹ��Ĭ������"
    cp /app/default_config.ini /config/config.ini || {
        echo "����: �޷�����Ĭ������" >&2
        exit 1
    }
fi

# ���/config/channel_rules.yml�����ڣ���ʹ��Ĭ������
if [ ! -f /config/channel_rules.yml ]; then
    echo "����: /config/channel_rules.yml �����ڣ�ʹ��Ĭ������"
    cp /app/channel_rules.yml /config/channel_rules.yml || {
        echo "����: �޷�����Ĭ��Ƶ����������" >&2
        exit 1
    }
fi

# ���������ļ�
sed -i "s#^timeout = .*#timeout = $TEST_TIMEOUT#" /config/config.ini
sed -i "s#^concurrent_threads = .*#concurrent_threads = $CONCURRENT_THREADS#" /config/config.ini
sed -i "s#^filename = .*#filename = $OUTPUT_FILENAME#" /config/config.ini

# ȷ����־Ŀ¼���ڲ�����ȷȨ��
mkdir -p /log || exit 1
touch /log/app.log /log/cron.log
chmod 666 /log/app.log /log/cron.log

# ȷ�����Ŀ¼����
mkdir -p /www/output
chmod 755 /www/output

# ȷ������Ŀ¼����
mkdir -p /config/online
chmod 755 /config/online

# ȷ������Ŀ¼����
mkdir -p /data
chmod 755 /data

# ����cron����
echo "$UPDATE_CRON /usr/local/bin/python /app/main.py >> /log/cron.log 2>&1" > /etc/cron.d/live-source-cron
chmod 0644 /etc/cron.d/live-source-cron
crontab /etc/cron.d/live-source-cron || {
    echo "����: crontab����ʧ��" >&2
    exit 1
}

# ����cron����
service cron start || {
    echo "����: �޷�����cron����" >&2
    exit 1
}

# ����Nginx����̨���У�
nginx -c /config/nginx.conf -g "daemon off;" &

# ��������ʱ��������һ������
echo "����ʱ��������һ������..."
python /app/main.py || {
    echo "����: ��ʼ����ִ��ʧ�ܣ�������������..." >&2
}

# �����������У������־��
tail -f /log/app.log /log/cron.log