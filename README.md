# 🌊 Survival of the Damned

**Survival of the Damned** é um jogo de sobrevivência oceânica em primeira pessoa (3D) desenvolvido na **Godot Engine 4.6**. Após um naufrágio em alto-mar, o jogador precisa sobreviver em uma jangada improvisada, mergulhar para coletar recursos que flutuam nas ondas, construir ferramentas e expandir sua estrutura em meio à imensidão do oceano.

---

## 🎮 Funcionalidades Implementadas (Progresso Atual)

### 🏊 Movimentação e Sobrevivência (Estilo *Subnautica* / *Raft*)
- **Movimentação Híbrida em 1ª Pessoa:** Transição fluida entre caminhada/corrida sobre a jangada e natação/mergulho livre tridimensional no oceano, com rampa submersa calibrada para subir na jangada caminhando diretamente da água.
- **Braços e Mãos Articulados em 1ª Pessoa (`FirstPersonRig`):** Sistema procedural de braços, mãos e dedos visíveis na câmera com animações dinâmicas para respiração (*idle*), balanço de caminhada/corrida, braçadas de nado na água e empunhadura anatômica de itens leves (como tábuas de madeira e o remo com ambas as mãos).
- **Status Vitais:** Sistema ativo de **Vida**, **Oxigênio** (consumido ao mergulhar com a cabeça submersa e regenerado na superfície), **Sede** e **Fome**.
- **Atmosfera Subaquática Dinâmica:** Mudança automática de iluminação ambiental, densidade de neblina (*fog*) e overlay visual ao submergir.

### 🚣 Jangada do Naufrágio (*Shipwreck Raft*) & Navegação
- **Oceano Infinito com Ondas em Shader:** Superfície marítima animada via `ocean.gdshader` que acompanha o deslocamento do jogador.
- **Física de Navegação a Remo:** Ao equipar o **Remo de Madeira**, o jogador pode remar continuamente para frente ou dar ré/manobrar a jangada na direção da câmera, movendo o personagem e todas as estruturas construídas junto com a embarcação.
- **Spawner Dinâmico de Recursos:** Pedaços de madeira flutuante (*Floating Wood*) surgem ao redor da jangada, derivam com a correnteza e oscilam acompanhando a matemática das ondas.

### 🎒 Inventário, HotBar e Crafting
- **HotBar de 6 Slots (`1` a `6`):** Equipamento rápido de itens e ferramentas com destaque visual no HUD.
- **Menu de Inventário e Criação (`Tab` ou `I`):**
  - **Remo de Madeira** (*Custo: 4 Madeiras*): Permite navegar e manobrar o raft pelo oceano.
  - **Baú de Armazenamento** (*Custo: 6 Madeiras*): Estrutura posicionável no convés da jangada.
- **Posicionamento de Estruturas com Preview 3D:** Ao selecionar o Baú na HotBar, um holograma indica em tempo real se a posição no deck da jangada é válida (verde) ou inválida/ocupada (vermelho), respeitando limites da embarcação e obstáculos existentes.
- **Sistema de Armazenamento:** Cada baú posicionado permite guardar e retirar até **50 madeiras** por meio de uma interface dedicada.

---

## 🕹️ Controles

| Tecla / Ação | Função |
| :--- | :--- |
| **W, A, S, D** | Movimentar na jangada / Nadar |
| **Shift** | Correr / Nadar rápido |
| **Espaço** | Pular (na jangada) / Subir à superfície (na água) |
| **Ctrl** | Mergulhar mais fundo |
| **E** | Interagir (Coletar madeira no mar / Abrir Baú) |
| **Tab** ou **I** | Abrir / Fechar Menu de Inventário e Crafting |
| **1 a 6** | Selecionar slots da HotBar |
| **Clique Esquerdo (Segurar)** | Remar para frente *(com Remo equipado sobre o raft)* |
| **Clique Direito (Segurar)** | Remar de ré *(com Remo equipado sobre o raft)* |
| **Clique Esquerdo** | Posicionar estrutura no convés *(com Baú equipado)* |
| **Esc** | Menu de Pausa e Opções (Sensibilidade do Mouse e FOV) |

---

## 🗂️ Estrutura do Projeto

```text
survival-of-the-damned/
├── scenes/
│   ├── items/
│   │   └── floating_wood.tscn      # Cena da madeira flutuante coletável
│   ├── player/
│   │   └── player.tscn             # Jogador 1ª pessoa, câmera, HUD e menus
│   ├── structures/
│   │   ├── shipwreck_raft.tscn     # Jangada inicial do naufrágio
│   │   └── storage_chest.tscn      # Estrutura de baú posicionável
│   └── world/
│       └── main_world.tscn         # Cena principal (Oceano, Iluminação, Spawner)
├── scripts/
│   ├── items/
│   │   └── floating_wood.gd        # Flutuação nas ondas e coleta
│   ├── player/
│   │   └── player.gd               # Movimentação, sobrevivência, inventário, craft e UI
│   ├── structures/
│   │   ├── shipwreck_raft.gd       # Física de navegação e validação de construção no deck
│   │   └── storage_chest.gd        # Lógica de capacidade e interação do baú
│   └── world/
│       └── ocean_environment.gd    # Atmosfera subaquática e spawner de recursos no mar
├── shaders/
│   └── ocean.gdshader              # Shader de ondas, espuma e reflexos do oceano
└── project.godot                   # Configurações do projeto Godot 4.6 (Jolt Physics)
```

---

## 🚀 Como Executar o Projeto

1. Instale a **[Godot Engine 4.6+](https://godotengine.org/)** (versão padrão GDScript).
2. Clone este repositório:
   ```bash
   git clone https://github.com/AlessandroAlves97/SurvivaloftheDamned.git
   ```
3. Abra o **Godot Project Manager**, clique em **Import** e selecione o arquivo `project.godot` na pasta clonada.
4. Pressione **F5** (ou clique no botão *Play* no canto superior direito) para iniciar o jogo.
