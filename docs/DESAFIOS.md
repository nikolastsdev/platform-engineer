# Desafios Enfrentados

1. **Leitura do PDF:** O arquivo é pequeno (3 páginas), mas contém todos os requisitos. A máquina não tinha `pdftotext`; usei `pymupdf` (Python).
2. **Arquivo `DESAFIO-PLATFORM-ENGINEER.pdf:Zone.Identifier`:** Arquivo de zona do Windows. Ignorado — não afeta o projeto.
3. **Aplicação `todolist-app`:** Já estava no diretório como submódulo (`todolist-app/`). Confirmado que roda localmente (`python app.py`).
4. **Terraform existente:** Já havia `cluster.tf` e `main.tf`. Preciso revisar para não sobrescrever sem verificar conteúdo.
5. **Ambiente Kubernetes:** Não há cluster rodando atualmente (`kubectl` não encontrado). Preciso criar via Kind.
6. **CI/CD:** Nenhum `.github/workflows` existente. Preciso criar pipeline de build -> deploy.
