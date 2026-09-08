#!/usr/bin/env python3
"""Promove a tag da imagem do app (image.tag) em k8s/helm/todolist-app/values.yaml.

Uso: promote-image.py <manifest> <nova_tag>

Promove SOMENTE a tag da imagem da aplicação — identificada por ser seguida
de `pullPolicy:`. Isso evita casar a tag do Postgres (postgresql.image.tag),
que também é uma linha `tag:` e vinha antes (bug que manteve o GitOps sem
efetuar deploy). Retorna exit code != 0 se a tag não for encontrada.
"""
import re
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(f"uso: {sys.argv[0]} <manifest> <nova_tag>", file=sys.stderr)
        return 2

    manifest, new_tag = sys.argv[1], sys.argv[2]
    with open(manifest, encoding="utf-8") as f:
        src = f.read()

    new_src, n = re.subn(
        # casa a linha `tag:` do bloco image: do app — identificada por ser
        # seguida (permitindo linhas de comentário) de `pullPolicy:`. Isso
        # evita casar postgresql.image.tag (que não tem pullPolicy).
        r"^(\s*tag:).*(?=\n(?:\s*#.*\n)*\s*pullPolicy:)",
        lambda m: m.group(1) + " " + new_tag,
        src,
        count=1,
        flags=re.M,
    )

    if n != 1:
        print(
            f"ERRO: nao encontrei a tag da imagem do app em {manifest} "
            "(linha `tag:` seguida de `pullPolicy:`)",
            file=sys.stderr,
        )
        return 1

    with open(manifest, "w", encoding="utf-8") as f:
        f.write(new_src)

    print(f"image.tag promovida -> {new_tag}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())