def smash_label_to_basename(l):
    bits = []
    if l.workspace_name != "":
        bits.append(l.workspace_name.strip('//'))
    bits.append(l.package.replace("/", "_"))
    bits.append(l.name.replace("/", "_"))
    return "_".join(bits)
