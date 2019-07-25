Param(
    [parameter(Mandatory = $true)] $ManagementIP
)

$KUBERNETES_VERSION="1.15.1"

Start-Service docker  

# tag the image kube uses for Pause
docker image pull mcr.microsoft.com/windows/nanoserver:1809
docker image tag mcr.microsoft.com/windows/nanoserver:1809 microsoft/nanoserver:latest

# download the Kube binaries
mkdir -p C:\k\logs
cd C:\k
$ProgressPreference=’SilentlyContinue’
iwr -outf kubernetes-node-windows-amd64.tar.gz "https://dl.k8s.io/v$KUBERNETES_VERSION/kubernetes-node-windows-amd64.tar.gz"

tar -xkf kubernetes-node-windows-amd64.tar.gz -C C:\k
mv C:\k\kubernetes\node\bin\*.exe C:\k

# install all the bits - adapted from
# https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/flannel/start.ps1

$NetworkMode="overlay"
$ClusterCIDR="10.244.0.0/16"
$KubeDnsServiceIP="10.96.0.10"
$ServiceCIDR="10.96.0.0/12"
$InterfaceName="Ethernet"
$LogDir="C:\k`logs"

$BaseDir = "c:\k"
$NetworkMode = $NetworkMode.ToLower()
$NetworkName = "vxlan0"
$GithubSDNRepository = 'Microsoft/SDN'

# Use helpers to setup binaries, conf files etc.
$helper = "c:\k\helper.psm1"
if (!(Test-Path $helper))
{
    Start-BitsTransfer "https://raw.githubusercontent.com/$GithubSDNRepository/master/Kubernetes/windows/helper.psm1" -Destination c:\k\helper.psm1
}
ipmo $helper

$install = "c:\k\install.ps1"
if (!(Test-Path $install))
{
    Start-BitsTransfer "https://raw.githubusercontent.com/$GithubSDNRepository/master/Kubernetes/windows/install.ps1" -Destination c:\k\install.ps1
}

# Download files, move them, & prepare network
powershell $install -NetworkMode "$NetworkMode" -clusterCIDR "$ClusterCIDR" -KubeDnsServiceIP "$KubeDnsServiceIP" -serviceCIDR "$ServiceCIDR" -InterfaceName "'$InterfaceName'" -LogDir "$LogDir"

# Register node
powershell $BaseDir\start-kubelet.ps1 -RegisterOnly -NetworkMode $NetworkMode
ipmo C:\k\hns.psm1
RegisterNode

# run kube components as Windows services - adapted from 
# https://raw.githubusercontent.com/microsoft/SDN/master/Kubernetes/flannel/register-svc.ps1

$KubeletSvc="kubelet"
$KubeProxySvc="kube-proxy"
$FlanneldSvc="flanneld2"
$Hostname=$(hostname).ToLower()

iwr -outf nssm.zip https://nssm.cc/ci/nssm-2.24-101-g897c7ad.zip
Expand-Archive nssm.zip
mv C:\k\nssm\nssm-2.24-101-g897c7ad\win64\*.exe C:\k

# register & start flanneld
.\nssm.exe install $FlanneldSvc C:\flannel\flanneld.exe
.\nssm.exe set $FlanneldSvc AppParameters --kubeconfig-file=c:\k\config --iface=$ManagementIP --ip-masq=1 --kube-subnet-mgr=1
.\nssm.exe set $FlanneldSvc AppEnvironmentExtra NODE_NAME=$Hostname
.\nssm.exe set $FlanneldSvc AppDirectory C:\flannel
.\nssm.exe start $FlanneldSvc

# register & start kubelet
.\nssm.exe install $KubeletSvc C:\k\kubelet.exe
.\nssm.exe set $KubeletSvc AppParameters --hostname-override=$Hostname --v=6 --pod-infra-container-image=mcr.microsoft.com/k8s/core/pause:1.0.0 --resolv-conf=""  --enable-debugging-handlers --cluster-dns=$KubeDnsServiceIP --cluster-domain=cluster.local --kubeconfig=c:\k\config --hairpin-mode=promiscuous-bridge --image-pull-progress-deadline=20m --cgroups-per-qos=false  --log-dir=$LogDir --logtostderr=false --enforce-node-allocatable="" --network-plugin=cni --cni-bin-dir=c:\k\cni --cni-conf-dir=c:\k\cni\config
.\nssm.exe set $KubeletSvc AppDirectory C:\k
.\nssm.exe start $KubeletSvc

# register & start kube-proxy
.\nssm.exe install $KubeProxySvc C:\k\kube-proxy.exe
.\nssm.exe set $KubeProxySvc AppDirectory c:\k
GetSourceVip -ipAddress $ManagementIP -NetworkName $NetworkName
$sourceVipJSON = Get-Content sourceVip.json | ConvertFrom-Json 
$sourceVip = $sourceVipJSON.ip4.ip.Split("/")[0]
.\nssm.exe set $KubeProxySvc AppParameters --v=4 --proxy-mode=kernelspace --feature-gates="WinOverlay=true" --hostname-override=$Hostname --kubeconfig=c:\k\config --network-name=vxlan0 --source-vip=$sourceVip --enable-dsr=false --cluster-cidr=$ClusterCIDR --log-dir=$LogDir --logtostderr=false
.\nssm.exe set $KubeProxySvc DependOnService $KubeletSvc
.\nssm.exe start $KubeProxySvc