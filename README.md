# QRadar Healthcheck

Quick healthcheck for QRadar deployments.

### Features
- Memory usage (For all managed hosts)
- Disk usage (For all managed hosts)
- CPU usage (For all managed hosts)
- Service status (For all managed hosts)
- Persistent queue (For all managed hosts)
- Spillover queue (For all managed hosts)
- System notifications (For all managed hosts)
- Mail queue
- Managed hosts status
- Installed applications status
- User interface and tomcat status
- High Availability status

### Samples

![Sample](https://github.com/krdmnbrk/qradar_healthcheck/blob/master/sample.png)
![Sample2](https://github.com/krdmnbrk/qradar_healthcheck/blob/master/sample2.png)

### Basic Usage
```
git clone https://github.com/krdmnbrk/qradar_healthcheck.git
cd qradar_healthcheck
bash qradar_healthcheck.sh
```
### Recommended Usage
1- Download the script

`git clone https://github.com/krdmnbrk/qradar_healthcheck.git`

2- Set an alias

`echo "alias qrhc='bash $(pwd)/qradar_healthcheck/qradar_healthcheck.sh'" >> ~/.bashrc`

3- Refresh your ssh connection

4- Type `qrhc`


