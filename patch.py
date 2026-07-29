# -*- coding: utf-8 -*-
import sys
content = open('e:/fabushi/.agents/plugins/plugins/chatgpt-auto-confirm/native/QueueWorker.swift', 'r', encoding='utf-8').read()
old_str = '''    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    let status = process.terminationStatus
    if status != 0 && status != 24 {
      queueTrace("rsync failed with status \(status)")
    }'''
new_str = '''    let pipe = Pipe()
    process.standardError = pipe
    process.standardOutput = pipe
    try process.run()
    process.waitUntilExit()
    let status = process.terminationStatus
    if status != 0 && status != 24 {
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? ""
      queueTrace("rsync failed with status \(status), output: \(output)")
    }'''
if old_str in content:
    content = content.replace(old_str, new_str)
    open('e:/fabushi/.agents/plugins/plugins/chatgpt-auto-confirm/native/QueueWorker.swift', 'w', encoding='utf-8', newline='\n').write(content)
    print('Replaced successfully')
else:
    print('Target not found')
