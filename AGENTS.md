# AGENTS.md — Polirotinas

## Objetivo

Este repositório contém o aplicativo Polirotinas e seus serviços de backend, automações e infraestrutura.

Repositório principal:
`brunopolii/app-do-poli`

## Regra principal

Quando o usuário solicitar uma alteração, NÃO faça apenas uma alteração superficial para atender ao texto do pedido.

Primeiro:

1. Analise a implementação atual.
2. Entenda como as partes envolvidas funcionam.
3. Identifique arquivos, dependências e integrações afetadas.
4. Escolha a solução mais segura, simples e compatível com a arquitetura existente.
5. Preserve funcionalidades existentes que não fazem parte da alteração solicitada.
6. Implemente a alteração completa.
7. Execute os testes e verificações disponíveis.
8. Corrija os problemas encontrados.
9. Verifique novamente após as correções.
10. Só considere a tarefa concluída quando o comportamento solicitado estiver realmente implementado.

## Autonomia

O Codex deve tomar as decisões técnicas necessárias para implementar corretamente o pedido.

Não peça ao usuário para escolher entre alternativas técnicas quando houver uma solução claramente melhor.

Se uma informação realmente indispensável estiver ausente, faça uma pergunta antes de fazer uma alteração potencialmente destrutiva.

Para problemas menores, erros de compilação, imports, dependências, formatação ou incompatibilidades decorrentes da própria alteração, corrija-os automaticamente.

## Segurança

* Nunca exponha secrets, API keys, tokens ou credenciais.
* Nunca coloque secrets diretamente no código.
* Use variáveis de ambiente, GitHub Secrets ou mecanismos apropriados.
* Não altere credenciais existentes.
* Não desative mecanismos de segurança apenas para fazer um teste funcionar.
* Não remova validações de licença ou autenticação sem autorização explícita.
* Não publicar dados privados no repositório.

## Git

O repositório principal é:

`brunopolii/app-do-poli`

Após concluir uma tarefa:

1. Verifique `git diff`.
2. Confirme que somente alterações relacionadas à tarefa foram feitas.
3. Execute os testes/verificações relevantes.
4. Faça commit com uma mensagem clara.
5. Faça push para a branch apropriada quando tiver autorização para isso.

Não faça commits contendo arquivos temporários, secrets, logs ou artefatos desnecessários.

## Flutter

Quando alterar o aplicativo Flutter:

1. Execute `flutter pub get` quando necessário.
2. Execute `flutter analyze`.
3. Execute os testes disponíveis.
4. Se a alteração afetar o APK, execute ou prepare `flutter build apk --release`.
5. Corrija erros encontrados antes de considerar a tarefa concluída.

Não remova funcionalidades existentes apenas para eliminar erros do analyzer.

## Backend

Antes de alterar o backend:

* Entenda as rotas existentes.
* Preserve contratos de API existentes quando possível.
* Valide entradas do usuário.
* Preserve CORS e mecanismos de autenticação existentes.
* Não exponha informações sensíveis nas respostas.
* Verifique compatibilidade com Cloudflare Workers e D1 quando essas partes forem afetadas.

## Licenciamento

O sistema de licenciamento do Polirotinas é sensível.

Ao alterar licenças:

* Não exponha chaves de licença publicamente.
* Não permita que uma pessoa obtenha uma licença sem a validação necessária.
* Preserve a associação da licença ao dispositivo quando essa regra fizer parte do sistema.
* Preserve os estados de licença existentes.
* Trate compras aprovadas, cancelamentos, reembolsos e chargebacks corretamente.
* Não coloque uma chave real diretamente em uma página pública.
* Testes devem utilizar dados de teste.

## Kiwify

Ao alterar a integração com a Kiwify:

* Preserve a autenticação existente.
* Preserve a sincronização de vendas.
* Preserve o tratamento de vendas aprovadas e canceladas/reembolsadas.
* Não coloque credenciais da Kiwify no código.
* Use GitHub Secrets ou variáveis de ambiente.
* Verifique os workflows antes de modificá-los.

## GitHub Actions

Ao alterar workflows:

1. Verifique a sintaxe YAML.
2. Confira secrets e variáveis utilizadas.
3. Verifique dependências entre jobs.
4. Não remover etapas existentes sem verificar seu propósito.
5. Quando possível, valide o workflow localmente ou por análise estática.
6. Se o workflow gerar APK, confirme que o caminho do artefato está correto.

## APK

O APK de produção deve ser gerado pelo workflow oficial do projeto.

Não substituir o APK de produção por um arquivo de teste sem autorização.

Quando uma alteração afetar o aplicativo Android, verificar se:

* o projeto compila;
* o APK release é gerado;
* o workflow continua funcionando;
* o artefato/release continua disponível.

## Princípio de preservação

Antes de modificar qualquer funcionalidade existente, descubra como ela funciona.

Não reescreva arquivos inteiros quando uma alteração localizada for suficiente.

Evite alterações desnecessárias.

## Conclusão da tarefa

Ao terminar, informe:

* o que foi alterado;
* quais arquivos foram modificados;
* quais testes foram executados;
* se algum problema foi encontrado e corrigido;
* o commit realizado;
* se o push foi realizado;
* qualquer pendência que realmente impeça considerar a tarefa concluída.
