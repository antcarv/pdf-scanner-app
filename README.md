# PDFscan

**PDFscan** é um aplicativo completo de escaneamento de documentos, extração de texto (OCR) e organização de arquivos, construído com Flutter. Ele permite que usuários digitalizem rapidamente documentos físicos usando a câmera do celular, transformem fotos da galeria em PDFs, e gerenciem seus arquivos de forma inteligente, tudo em uma interface moderna e "dark mode".

## Funcionalidades Principais

*   **Scanner Inteligente:** Escaneie documentos com detecção automática e inteligente de bordas usando a câmera do dispositivo.
*   **Importação da Galeria:** Selecione e importe imagens já existentes na galeria para criar PDFs rapidamente.
*   **Extração de Texto (OCR):** Reconhecimento de caracteres via Google ML Kit. O app extrai o texto da imagem instantaneamente após o scan.
*   **Integração com a IA do Gemini:** Um clique basta para copiar o texto extraído (OCR) e abrir o **Google Gemini** para reescrever, resumir ou traduzir o texto do seu documento.
*   **Gerenciamento e Pastas:** Visualize os documentos escaneados recentes e organize-os em pastas criadas por você.
*   **Aba Arquivos (Organizador Completo):** Acesse todos os arquivos suportados (PDF, DOCX, Imagens) baixados no seu dispositivo através da aba "Arquivos". Você pode copiar ou mover esses documentos externos para as pastas geridas pelo aplicativo, centralizando toda sua vida documental num só lugar.
*   **Exportação Multiformato:** Exporte os scans não só como PDF, mas também como **documentos de Word (DOCX)** ou imagens individuais em JPEG.
*   **Compartilhamento Ágil:** Compartilhe documentos via WhatsApp, Email e etc. com a funcionalidade de compartilhamento nativo.
*   **Tradução Nativa:** Suporte a Português e Inglês com troca rápida através do menu principal.

## Telas do Aplicativo

### Tela Principal (Home Screen)
A Home é o coração do app e conta com uma navegação em abas:
*   **Recentes:** Mostra todos os documentos e imagens processados recentemente.
*   **Pastas:** Área de organização, permitindo que você crie diretórios locais e classifique seus arquivos processados ou externos.
*   **Arquivos:** Uma aba poderosa que lê os arquivos da pasta Downloads do celular. Assim, você pode capturar aquele boleto que acabou de baixar e mandá-lo para uma das suas Pastas criadas no app.

### Scanner e Menu de Ações (Floating Button)
O botão colorido flutuante ativa as opções de Scanear via câmera, importar múltiplas imagens da galeria ou extrair texto de uma única foto.

### Tela de Pré-visualização e Edição
Ao concluir o scan, o usuário entra no modo Preview. Esta tela:
*   Exibe o PDF finalizado.
*   Contém um card exclusivo por página, mesclando a imagem cortada e a aba de texto com o OCR finalizado.
*   Fornece acesso imediato aos botões **Copiar Texto** e **Gemini** (para acionar a IA baseada no conteúdo recém-escaneado).
*   Oferece as opções de salvar no histórico ou exportar para DOCX/PDF.

## Tecnologias e Pacotes Utilizados
*   `flutter`: Framework base.
*   `cunning_document_scanner`: Scanner de documentos (Camera/Cropping Nativo).
*   `google_mlkit_text_recognition`: Leitura de texto local.
*   `pdf`: Criação do arquivo de PDF.
*   `docx_creator`: Geração de arquivos do Word.
*   `permission_handler`: Pedido e verificação de acesso ao armazenamento completo no Android.
*   `path_provider`: Gestão de diretórios de arquivos locais.
*   `shared_preferences`: Salvamento de estado local (histórico, pastas).
*   `share_plus`: API de compartilhamento nativo do Android/iOS.
*   `open_filex`: Abertura de PDFs e Docx visualizadores instalados.

## Versão Atual
`1.1.0+3`

Desenvolvido por Antonio Carvalho.
