# 🎯 Como Adicionar Plugins / Abas / Botões no DeepSeek Harness

> Baseado na documentação interna: `/home/nikolasschaffer/.local/share/nvm/v24.19.0/lib/node_modules/@deepseek-ai/dsh/config/agent-presets/cordis/skills/cordis-plugin-development/SKILL.md`

## Como o Harness funciona

O DeepSeek Harness (http://127.0.0.1:3080) é um app **React + Cordis** (sistema de plugins).
Qualquer "aba", "botão", "painel" é um **plugin Cordis** que se registra num **Slot** específico.

A anatomia é:

```
plugin  →  cordis_define  →  cordis_run  →  aparece no GUI
                                              (Slots, botões, abas, etc)
```

Não há "menu de instalar plugin" no GUI. A única forma de adicionar UI é via `cordis_define` + `cordis_run`, que estão disponíveis **apenas quando você roda o preset `cordis`**.

---

## 📋 Passo-a-passo para adicionar uma aba/função no GUI

### 1) Rode o harness no preset `cordis`

Esse preset tem as tools `cordis_define`, `cordis_run`, `cordis_inspect_list`, `cordis_inspect_query`, `cordis_inspect_self`, `cordis_stop`, `cordis_undefine`.

### 2) Descubra os Slots disponíveis

```js
// Chamada cordis_inspect_list com root = 'slots' (descobre a árvore de slots)
{
  root: 'slots',
  // retorna: sidebar, conversation, conversation.chat.turnTail,
  //          tool.view.cordis, settings.section, shell.overlay, etc.
}
```

### 3) Inspecione o Slot específico

Antes de registrar, use `cordis_inspect_query` para saber:
- protocolo (`single` / `list` / `keyed` / `chain`)
- opções (`key`, `id`, `selector`)
- props padrão e do owner
- quem já está ocupando (risco de substituir)

```js
// Exemplo: ver o que aceita "sidebar.footer.action"
cordis_inspect_query('slots', 'sidebar.footer.action')
```

### 4) Escreva o código do plugin (Slot registration)

```js
return {
  apply(ctx) {
    const slots = ctx.get('slots')
    if (slots === undefined) return

    // Espera o slot e registra um painel
    slots.inject('sidebar.footer.action', () => slots.register(
      { name: 'sidebar.footer.action', id: 'mermaid-tab' },
      (props) => React.createElement('div', null, 'Mermaid tab!')
    ))
  }
}
```

### 5) Defina e rode

```js
// cordis_define recebe o código acima
// cordis_run executa
// → Slot aparece no GUI imediatamente
```

---

## 🎯 Slots úteis para plugins comuns

| Slot | Onde aparece | Bom para |
|---|---|---|
| `tool.view.cordis` (com `key: 'self'`) | Card do cordis_run | UIs ligadas à resposta do agente |
| `sidebar.footer.action` | Rodapé da barra lateral | Botões pequenos |
| `conversation.chat.turnTail` | Depois de uma mensagem | Conteúdo extra |
| `settings.section` | Painel de configurações | Settings completos |
| `shell.overlay` | Overlays/toasts | Notificações |
| `tool.call.toolview` (key = nome da tool) | Card de chamada de tool | Customizar cards de tool |

---

## 💻 Exemplo: plugin "Mermaid Tab" no `tool.view.cordis`

```js
return {
  apply(ctx) {
    const slots = ctx.get('slots')
    if (slots === undefined) return

    // Carrega Mermaid CDN
    if (!document.getElementById('mermaid-cdn')) {
      const s = document.createElement('script')
      s.id = 'mermaid-cdn'
      s.src = 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js'
      document.head.appendChild(s)
    }

    // Adiciona CSS
    if (!document.getElementById('mermaid-style')) {
      const s = document.createElement('style')
      s.id = 'mermaid-style'
      s.textContent = `
        .mermaid-panel { background: #0f172a; color: #f8fafc;
                          padding: 16px; border-radius: 12px;
                          margin: 12px 0; }
        .mermaid-panel h2 { color: #38bdf8; }
        pre.mermaid { background: #1e293b; padding: 16px;
                       border-radius: 8px; }
      `
      document.head.appendChild(s)
    }

    slots.inject('tool.view.cordis', () => slots.register(
      { name: 'tool.view.cordis', key: 'self' },
      (props) => {
        // Quando Mermaid carregar, renderiza os diagramas
        setTimeout(() => {
          if (window.mermaid) {
            window.mermaid.initialize({ startOnLoad: true, theme: 'dark' })
          }
        }, 100)

        return React.createElement('div', { className: 'mermaid-panel' },
          React.createElement('h2', null, '📊 Mermaid View'),
          React.createElement('pre', { className: 'mermaid' },
            'flowchart TB\n    A-->B-->C'
          )
        )
      }
    ))
  }
}
```

---

## ⚠️ Regras importantes

1. **Use `ctx.get('slots')` com `if (undefined) return`** — não é `inject: ['slots']` por padrão
2. **Não adivinhe `id`, `key`, props** — sempre consulte com `cordis_inspect_query`
3. **Substituir um occupant apaga descendentes** — prefira Slots aditivos
4. **TODA contribuição deve ser disposed** — use `ctx.effect()`, `ctx.on()`, retenha o disposer
5. **Não manipule `document.body` ou `window` globalmente** — use `styles.insert(css)` e Slot API
6. **Não use `setTimeout` direto** — use `ctx.timeout()` (Service `timer`)

---

## 🧪 Onde conseguir ajuda prática

A skill `cordis-plugin-development` no preset cordis já tem este guia. A skill `editing-cordis-compositions` ensina a criar composições inteiras.

Quando estiver rodando no preset `cordis`, peça ao agente:
> "Use `cordis_inspect_list` com root 'slots' e me mostre a árvore completa"
> "Crie um plugin que registra um botão no `sidebar.footer.action`"
> "Use `cordis_define` com o código X e depois `cordis_run`"

---

## 📂 Arquivos úteis no projeto

| Arquivo | Conteúdo |
|---|---|
| `dsh-plugin-mermaid/client/tab-plugin.js` | Código pronto para colar no `cordis_define` |
| `dsh-plugin-mermaid/client/mermaid-tab.html` | Preview standalone (sem harness) |
| `dsh-plugin-mermaid/bin/md-preview.js` | Servidor HTTP local (preview) |
| `dsh-plugin-mermaid/lib/index.js` | API da Service (extração, render) |

---

## 🎬 TL;DR

**Como adicionar plugin no harness:**

1. Abre o DSH no **preset `cordis`** (esse tem as tools necessárias)
2. Pergunta ao agente: "list os slots disponíveis" (usa `cordis_inspect_list`)
3. Pede: "crie um plugin que registra um botão no `sidebar.footer.action`"
4. O agente executa `cordis_define` + `cordis_run`
5. A UI aparece no harness

**É a única forma. Não tem menu "Instalar Plugin" no GUI** — o caminho é sempre via tools do preset `cordis`.
