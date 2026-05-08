
// 用途：用于清理本地 Maven 仓库中过时的 SNAPSHOT 文件 和 `.lastUpdated` 文件
// 使用方法：在 Shell 中运行该文件：`groovy clean-mvn-repository.groovy` (前提条件是本地已经配置好 Groovy 的开发环境)

// Maven 仓库路径
def m2repo = System.getProperty('user.home') + '/.m2/repository'

count = 0
delCount = 0

start = System.currentTimeMillis()

def dirsToDelete = []
pattern = /.*\-\d{8}\.\d{6}\-\d+\.[\w\.]+$/

new File(m2repo).eachFileRecurse {
    count++
    try {
        if (it.isDirectory() && it.name == 'unknown') {
            // 清理垃圾目录： unknown
            dirsToDelete << it
        } else if (it.isFile() && it.name.matches(pattern)) {
            // 清理垃圾 snapshot jar：xxxx-1.0-SNAPSHOT-20231027.153045-1.jar
            println "Deleting ${it.name}" + ", file length [${it.length()}] bytes."
            it.delete()
            delCount++
        } else if (it.isFile() && (it.name.endsWith('.lastUpdated') || it.name.endsWith('.jar.part'))) {
            // 清理垃圾文件： *.lastUpdated 和 *.jar.part
            println "Deleting ${it.name}" + ", file length [${it.length()}] bytes."
            it.delete()
            delCount++
        }
    } catch (Exception e) {
        println "Error processing ${it.path}: ${e.message}"
    }
}

// 统一删除收集到的 unknown 目录
dirsToDelete.each { dir ->
    println "Deleting directory: ${dir.absolutePath}"
    if (dir.deleteDir()) {
        delCount++ // 这里计数代表删除的目录数，如需精确到文件数需另行统计
    } else {
        println "Failed to delete directory: ${dir.absolutePath}"
    }
}

println ">>> 删除成功, 总文件：$count, 删除文件：$delCount, 保留文件：${count - delCount}, time: ${System.currentTimeMillis() - start} ms"