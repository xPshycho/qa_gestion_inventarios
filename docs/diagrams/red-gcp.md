# Red GCP observada

```mermaid
flowchart LR
  INTERNET((Internet))
  IAP[Google IAP\n35.235.240.0/20]
  subgraph DEFAULT["VPC default · us-central1"]
    VM[qa-inventario\n10.128.0.2\n34.123.136.144]
  end
  subgraph DEVNET["inventory-development-network"]
    SUB[serverless subnet\n10.10.0.0/24]
    SQL2[(Cloud SQL dev privada\n10.247.0.3\nRUNNABLE)]
  end
  subgraph STGNET["inventory-staging-network"]
    SSUB[serverless subnet\n10.20.0.0/24]
    SQL3[(Cloud SQL staging privada\n10.188.0.3\nRUNNABLE)]
  end
  RUN[Cloud Run público\ninventory-development]
  PROXY[Cloud SQL Proxy sidecar]
  SQL1[(Cloud SQL pública\nsin authorized networks\nRUNNABLE)]

  INTERNET -->|TCP 80/443| VM
  IAP -->|TCP 22| VM
  INTERNET -->|HTTPS allUsers| RUN
  RUN --> PROXY
  PROXY --> SQL1
  SUB -. plataforma en convergencia .-> SQL2
  SSUB -. sin Cloud Run staging observado .-> SQL3
```

Firewall de la VM no abre puertos de aplicación internos. La instancia SQL
pública exige proxy/conector; no tiene redes autorizadas observadas. La
Las instancias privadas aparecieron durante la auditoría y terminaron
`RUNNABLE`, pero no se observaron servicios Cloud Run consumidores.
