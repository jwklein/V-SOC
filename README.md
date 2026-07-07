# Overview
```mermaid
---
config:
  layout: fixed
---
flowchart TB
 subgraph vmbr0["vmbr0 (Upstream Bridge)"]
        IaCcontroller["IaC-controller<br>(Container)"]
        wazuhdashboard["wazuh-dashboard"]
        kaliwander["kali-wan"]
        opnsenseupstream["opnsense<br>(WAN NIC)"]
  end
 subgraph metasploitable3_grp["metasploitable3-win2k8 Cluster"]
        metasploitable3win["metasploitable3-win2k8"]
        wazuhagent1["wazuh-agent"]
  end
 subgraph cowrie_grp["cowrie Cluster"]
        cowrie["cowrie"]
        wazuhagent2["wazuh-agent"]
  end
 subgraph vmbr10["vmbr10 (Downstream Bridge)"]
        opnsensedownstream["opnsense<br>(LAN NIC)"]
        wazuhmanager["wazuh manager-indexer"]
        kaluran["kali-lan"]
        metasploitable3_grp
        cowrie_grp
  end
    opnsenseupstream --> n1["opnsense<br>Firewall"]
    n1 --> opnsensedownstream

    n1@{ shape: rect}
     IaCcontroller:::container
     wazuhdashboard:::host
     kaliwander:::host
     opnsenseupstream:::firewall
     metasploitable3win:::host
     wazuhagent1:::agent
     cowrie:::host
     wazuhagent2:::agent
     opnsensedownstream:::firewall
     wazuhmanager:::host
     kaluran:::host
     n1:::firewall
     vmbr0:::upstream
    classDef upstream fill:#eef2ff,stroke:#818cf8
    classDef downstream fill:#f0fdfa,stroke:#2dd4bf
    classDef container fill:#fff7ed,stroke:#fb923c
    classDef firewall fill:#fdf4ff,stroke:#e879f9
    classDef host fill:#f0f9ff,stroke:#38bdf8
    classDef agent fill:#fefce8,stroke:#facc15
```


# Dependencies

This project was designed around a specific proxmox environment for Miami University. Therefore the repository assumes a set of Golden-Image Dependencies necessary for deployment, and a set of secrets within the host machine running deployment that are not included in the repo. All of which will be enumerated and explained.

