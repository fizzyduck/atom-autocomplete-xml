# This will catch:
# * Start tags: <tagName
# * End tags: </tagName
# * Auto close tags: />
# * Comment start: <!--
# * Comment end: -->
# * CDATA section start: <![CDATA[
# * CDATA section end: ]]>
startTagPattern = '<\s*[\\.\\-:_a-zA-Z0-9]+'
endTagPattern = '<\\/\s*[\\.\\-:_a-zA-Z0-9]+'
autoClosePattern = '\\/>'
startCommentPattern = '\s*<!--'
endCommentPattern = '\s*-->'
startCDATAPattern = '\s*<!\\[CDATA\\['
endCDATAPattern = '\s*\\]\\]>'
fullPattern = new RegExp("(" +
  startTagPattern + "|" + endTagPattern + "|" + autoClosePattern + "|" +
  startCommentPattern + "|" + endCommentPattern + "|" +
  startCDATAPattern + "|" + endCDATAPattern + ")", "g")
wordPattern = new RegExp('^(\\w+)')


module.exports =
  getXPathWithPrefix: (buffer, bufferPosition, prefix, maxDepth) ->
    {row, column} = bufferPosition
    column -= prefix.length
    return @getXPath(buffer, row, column, maxDepth)


  getXPathCompleteWord: (buffer, bufferPosition, maxDepth) ->
    {row, column} = bufferPosition

    # Try to get the end of the current word if any
    line = buffer.lineForRow(row).slice(column)
    wordMatch = line.match(wordPattern)
    column += wordMatch[1].length if wordMatch

    return @getXPath(buffer, row, column, maxDepth)


  getXPath: (buffer, row, column, maxDepth) ->
    # For every row, checks if it's an open, close, or autoopenclose tag and
    # update a list of all the open tags.
    xpath = []
    skipList = []
    waitingStartTag = false
    waitingStartComment = false
    waitingStartCDATA = false

    # For the first line read removing the prefix
    line = buffer.getTextInRange([[row, 0], [row, column]])

    while row >= 0 and (!maxDepth or xpath.length < maxDepth)
      row--

      # Apply the regex expression, read from right to left.
      matches = line.match(fullPattern)
      matches?.reverse()

      for match in matches ? []
        # Start comment
        if match == "<!--"
          waitingStartComment = false
        # End comment
        else if match == "-->"
          # Comment markup should be ignored inside CDATA sections
          unless waitingStartCDATA
            waitingStartComment = true
        # Omit comment content
        else if waitingStartComment
          continue
        # Start CDATA
        else if match == "<![CDATA["
          waitingStartCDATA = false
        # End CDATA
        else if match == "]]>"
          waitingStartCDATA = true
        # Omit CDATA content
        else if waitingStartCDATA
          continue
        # Auto tag close
        else if match == "/>"
          waitingStartTag = true
        # End tag
        else if match[0] == "<" && match[1] == "/"
          skipList.push match.slice 2
        # This should be a start tag
        else if match[0] == "<" && waitingStartTag
          waitingStartTag = false
        else if match[0] == "<"
          tagName = match.slice 1

          # Ommit XML definition.
          if tagName == "?xml"
            continue

          idx = skipList.lastIndexOf tagName
          if idx != -1 then skipList.splice idx, 1 else xpath.push tagName

      # Get next line
      line = buffer.lineForRow(row)

    return xpath.reverse()
