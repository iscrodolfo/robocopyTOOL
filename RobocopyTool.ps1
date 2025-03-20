# Verificar si se ejecuta como administrador, de no ser así, reiniciar como administrador
$myShell = New-Object -ComObject Shell.Application
$runAsAdmin = [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups -match "S-1-5-32-544"

if (-not $runAsAdmin) {
    # Reiniciar el script con privilegios de administrador
    $myShell.ShellExecute("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"", "", "runas", 1)
    exit
}

# Cargar las librerías de Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Función para verificar si el origen es un archivo ZIP y extraerlo si es necesario
function Extraer-zip {
    param ($zipFilePath, $destinationPath)
    
    if (Test-Path $zipFilePath -and $zipFilePath.EndsWith(".zip")) {
        try {
            # Extraer el archivo ZIP
            Write-Host "Extrayendo el archivo ZIP..."
            Expand-Archive -Path $zipFilePath -DestinationPath $destinationPath -Force
            Write-Host "Archivo ZIP extraído exitosamente."
        } catch {
            Write-Host "Error al extraer el archivo ZIP: $_"
            return $false
        }
    } else {
        Write-Host "El archivo especificado no es un archivo ZIP o no existe."
        return $false
    }
    
    return $true
}

try {
    # Crear la ventana de la interfaz gráfica
    $ventana = New-Object System.Windows.Forms.Form
    $ventana.Text = "RobocopyTool"
    $ventana.Size = New-Object System.Drawing.Size(600, 700)  # Ajuste tamaño para la nueva funcionalidad
    $ventana.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $ventana.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $ventana.MaximizeBox = $false
    $ventana.Icon = [System.Drawing.SystemIcons]::Application

    # Personalización del fondo de la ventana
    $ventana.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)  # Color gris suave de Windows 10/11

    # Título grande
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "RobocopyTool"
    $lblTitle.Font = New-Object System.Drawing.Font("Arial", 24, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(10, 20)
    $lblTitle.Size = New-Object System.Drawing.Size(580, 40)
    $lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $ventana.Controls.Add($lblTitle)

    # Variables globales para rastrear múltiples archivos
    $global:selectedFiles = @()
    $global:isMultipleFiles = $false
    $global:isDirectory = $false

    # Etiqueta y caja de texto para la ruta de origen
    $origenLabel = New-Object System.Windows.Forms.Label
    $origenLabel.Text = "Selecciona Archivos o Carpeta de Origen:"
    $origenLabel.Location = New-Object System.Drawing.Point(10, 80)
    $origenLabel.Size = New-Object System.Drawing.Size(400, 20)
    $ventana.Controls.Add($origenLabel)

    $txtOrigen = New-Object System.Windows.Forms.TextBox
    $txtOrigen.Location = New-Object System.Drawing.Point(10, 100)
    $txtOrigen.Size = New-Object System.Drawing.Size(400, 20)
    $txtOrigen.BackColor = [System.Drawing.Color]::White
    $txtOrigen.ForeColor = [System.Drawing.Color]::Black
    $txtOrigen.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtOrigen.ReadOnly = $true  # Hacemos el TextBox de solo lectura para evitar errores de formato
    $ventana.Controls.Add($txtOrigen)

    # Botones de radio para elegir el tipo de selección
    $radioPanel = New-Object System.Windows.Forms.Panel
    $radioPanel.Location = New-Object System.Drawing.Point(10, 125)
    $radioPanel.Size = New-Object System.Drawing.Size(400, 30)
    $ventana.Controls.Add($radioPanel)

    $radioArchivos = New-Object System.Windows.Forms.RadioButton
    $radioArchivos.Text = "Seleccionar Archivos"
    $radioArchivos.Location = New-Object System.Drawing.Point(0, 0)
    $radioArchivos.Size = New-Object System.Drawing.Size(200, 20)
    $radioArchivos.Checked = $true
    $radioPanel.Controls.Add($radioArchivos)

    $radioCarpeta = New-Object System.Windows.Forms.RadioButton
    $radioCarpeta.Text = "Seleccionar Carpeta"
    $radioCarpeta.Location = New-Object System.Drawing.Point(200, 0)
    $radioCarpeta.Size = New-Object System.Drawing.Size(200, 20)
    $radioPanel.Controls.Add($radioCarpeta)

    # Botón para seleccionar la carpeta o archivo de origen
    $btnOrigen = New-Object System.Windows.Forms.Button
    $btnOrigen.Text = "Seleccionar Origen"
    $btnOrigen.Location = New-Object System.Drawing.Point(420, 100)
    $btnOrigen.Size = New-Object System.Drawing.Size(150, 25)
    $btnOrigen.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnOrigen.ForeColor = [System.Drawing.Color]::White
    $btnOrigen.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnOrigen.FlatAppearance.BorderSize = 0
    $btnOrigen.Add_Click({
        if ($radioArchivos.Checked) {
            # Seleccionar archivos
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = "Todos los archivos (*.*)|*.*"
            $dialog.Title = "Seleccionar archivos de origen"
            $dialog.Multiselect = $true
            if ($dialog.ShowDialog() -eq 'OK') {
                $global:selectedFiles = $dialog.FileNames
                $global:isMultipleFiles = ($global:selectedFiles.Count -gt 1)
                $global:isDirectory = $false
                
                if ($global:isMultipleFiles) {
                    $txtOrigen.Text = "Mltiples archivos seleccionados (" + $global:selectedFiles.Count + " archivos)"
                } else {
                    $txtOrigen.Text = $global:selectedFiles[0]
                }
            }
        } else {
            # Seleccionar carpeta
            $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            if ($folderBrowser.ShowDialog() -eq 'OK') {
                $txtOrigen.Text = $folderBrowser.SelectedPath
                $global:selectedFiles = @($folderBrowser.SelectedPath)
                $global:isMultipleFiles = $false
                $global:isDirectory = $true
            }
        }
    })
    $ventana.Controls.Add($btnOrigen)

    # Etiqueta y caja de texto para la ruta de destino
    $destinoLabel = New-Object System.Windows.Forms.Label
    $destinoLabel.Text = "Selecciona Carpeta de Destino:"
    $destinoLabel.Location = New-Object System.Drawing.Point(10, 160)
    $destinoLabel.Size = New-Object System.Drawing.Size(400, 20)
    $ventana.Controls.Add($destinoLabel)

    $txtDestino = New-Object System.Windows.Forms.TextBox
    $txtDestino.Location = New-Object System.Drawing.Point(10, 180)
    $txtDestino.Size = New-Object System.Drawing.Size(400, 20)
    $txtDestino.BackColor = [System.Drawing.Color]::White
    $txtDestino.ForeColor = [System.Drawing.Color]::Black
    $txtDestino.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $txtDestino.ReadOnly = $true  # También lo hacemos de solo lectura
    $ventana.Controls.Add($txtDestino)

    # Botón para seleccionar la carpeta de destino
    $btnDestino = New-Object System.Windows.Forms.Button
    $btnDestino.Text = "Seleccionar Destino"
    $btnDestino.Location = New-Object System.Drawing.Point(420, 180)
    $btnDestino.Size = New-Object System.Drawing.Size(150, 25)
    $btnDestino.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnDestino.ForeColor = [System.Drawing.Color]::White
    $btnDestino.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnDestino.FlatAppearance.BorderSize = 0
    $btnDestino.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        if ($folderBrowser.ShowDialog() -eq 'OK') {
            $txtDestino.Text = $folderBrowser.SelectedPath
        }
    })
    $ventana.Controls.Add($btnDestino)

    # Barra de progreso
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Location = New-Object System.Drawing.Point(10, 220)
    $progressBar.Size = New-Object System.Drawing.Size(560, 20)
    $progressBar.Minimum = 0
    $progressBar.Maximum = 100
    $progressBar.Value = 0
    $ventana.Controls.Add($progressBar)

    # Área de texto para mostrar los logs
    $txtLogs = New-Object System.Windows.Forms.TextBox
    $txtLogs.Location = New-Object System.Drawing.Point(10, 250)
    $txtLogs.Size = New-Object System.Drawing.Size(560, 140)
    $txtLogs.Multiline = $true
    $txtLogs.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $txtLogs.ReadOnly = $true
    $txtLogs.BackColor = [System.Drawing.Color]::FromArgb(0, 0, 0)  # Fondo negro para los logs
    $txtLogs.ForeColor = [System.Drawing.Color]::White  # Texto blanco para resaltar el log
    $txtLogs.Font = New-Object System.Drawing.Font("Consolas", 9)
    $ventana.Controls.Add($txtLogs)

    # Botón de iniciar copiado
    $btnCopiar = New-Object System.Windows.Forms.Button
    $btnCopiar.Text = "Iniciar Copiado"
    $btnCopiar.Location = New-Object System.Drawing.Point(400, 400)
    $btnCopiar.Size = New-Object System.Drawing.Size(170, 30)
    $btnCopiar.BackColor = [System.Drawing.Color]::FromArgb(0, 163, 0)  # Color verde para el botón de inicio
    $btnCopiar.ForeColor = [System.Drawing.Color]::White
    $btnCopiar.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnCopiar.FlatAppearance.BorderSize = 0
    $btnCopiar.Add_Click({
        # Verificar selecciones de origen y destino
        if ($global:selectedFiles.Count -eq 0 -or [string]::IsNullOrEmpty($txtDestino.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Por favor, seleccione las rutas de origen y destino.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return
        }

        # Limpiar el área de logs
        $txtLogs.Text = ""
        $txtLogs.AppendText("=== INICIANDO PROCESO DE COPIADO ===`r`n")
        $txtLogs.AppendText("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Iniciando operacion...`r`n")

        # Verificar si es un archivo o una carpeta
        foreach ($file in $global:selectedFiles) {
            if (Test-Path $file) {
                if (Test-Path "$file\*") {
                    # Si es una carpeta, copiar con robocopy
                    $dest = Join-Path -Path $txtDestino.Text -ChildPath (Split-Path -Leaf $file)
                    $command = "robocopy `"$file`" `"$dest`" /E /Z /MIR"
                    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $command" -NoNewWindow -Wait -PassThru
                    $process.WaitForExit()

                    $txtLogs.AppendText("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Copiado: $file -> $dest`r`n")
                    $progressBar.Value = [math]::Round(($global:selectedFiles.IndexOf($file) + 1) / $global:selectedFiles.Count * 100)
                } else {
                    # Si es un archivo, copiar directamente
                    $dest = Join-Path -Path $txtDestino.Text -ChildPath (Split-Path -Leaf $file)
                    Copy-Item -Path $file -Destination $dest

                    $txtLogs.AppendText("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Copiado archivo: $file -> $dest`r`n")
                    $progressBar.Value = [math]::Round(($global:selectedFiles.IndexOf($file) + 1) / $global:selectedFiles.Count * 100)
                }
            }
        }

        $txtLogs.AppendText("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Copiado completado.`r`n")

        # Rehabilitar controles
        $btnCopiar.Enabled = $true
        $btnOrigen.Enabled = $true
        $btnDestino.Enabled = $true
    })
    $ventana.Controls.Add($btnCopiar)

    # Botón Limpiar
    $btnLimpiar = New-Object System.Windows.Forms.Button
    $btnLimpiar.Text = "Limpiar"
    $btnLimpiar.Location = New-Object System.Drawing.Point(400, 440)
    $btnLimpiar.Size = New-Object System.Drawing.Size(170, 30)
    $btnLimpiar.BackColor = [System.Drawing.Color]::FromArgb(255, 0, 0)  # Color rojo para el botón de limpiar
    $btnLimpiar.ForeColor = [System.Drawing.Color]::White
    $btnLimpiar.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnLimpiar.FlatAppearance.BorderSize = 0
    $btnLimpiar.Add_Click({
        # Limpiar los campos de texto y la variable de archivos seleccionados
        $txtOrigen.Clear()
        $txtDestino.Clear()
        $txtLogs.Clear()
        $global:selectedFiles = @()
    })
    $ventana.Controls.Add($btnLimpiar)
	
	
# Botón de información del desarrollador (YouTube)
$btnInfoYouTube = New-Object System.Windows.Forms.Button
$btnInfoYouTube.Text = "YouTube"
$btnInfoYouTube.Location = New-Object System.Drawing.Point(10, 520)  # Ajustado a una nueva ubicación
$btnInfoYouTube.Size = New-Object System.Drawing.Size(170, 30)
$btnInfoYouTube.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)  # Color azul
$btnInfoYouTube.ForeColor = [System.Drawing.Color]::White
$btnInfoYouTube.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInfoYouTube.FlatAppearance.BorderSize = 0
$btnInfoYouTube.Add_Click({
    Start-Process "https://www.youtube.com/@iscrodolfoalvarez"
})
$ventana.Controls.Add($btnInfoYouTube)

# Botón de información del desarrollador (GitHub)
$btnInfoGitHub = New-Object System.Windows.Forms.Button
$btnInfoGitHub.Text = "GitHub"
$btnInfoGitHub.Location = New-Object System.Drawing.Point(190, 520)  # Ajustado a una nueva ubicación
$btnInfoGitHub.Size = New-Object System.Drawing.Size(170, 30)
$btnInfoGitHub.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)  # Color azul
$btnInfoGitHub.ForeColor = [System.Drawing.Color]::White
$btnInfoGitHub.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInfoGitHub.FlatAppearance.BorderSize = 0
$btnInfoGitHub.Add_Click({
    Start-Process "https://github.com/iscrodolfo"
})
$ventana.Controls.Add($btnInfoGitHub)

# Botón de información del desarrollador (PayPal)
$btnInfoPayPal = New-Object System.Windows.Forms.Button
$btnInfoPayPal.Text = "Donar a traves de PayPal"
$btnInfoPayPal.Location = New-Object System.Drawing.Point(370, 520)  # Ajustado a una nueva ubicación
$btnInfoPayPal.Size = New-Object System.Drawing.Size(170, 30)
$btnInfoPayPal.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)  # Color azul
$btnInfoPayPal.ForeColor = [System.Drawing.Color]::White
$btnInfoPayPal.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInfoPayPal.FlatAppearance.BorderSize = 0
$btnInfoPayPal.Add_Click({
    Start-Process "https://www.paypal.com/paypalme/rodolfoalvarez90"
})
$ventana.Controls.Add($btnInfoPayPal)

	
	

    # Mostrar la ventana
    [void]$ventana.ShowDialog()

} catch {
    Write-Host "Error al crear la interfaz: $($_.Exception.Message)"
}
