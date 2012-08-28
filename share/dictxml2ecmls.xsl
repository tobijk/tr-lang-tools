<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:param name="title"/>
    <xsl:param name="author"/>

    <xsl:template match="/vocabulary">
<article lang="en_US" fontsize="11pt" papersize="a5paper" div="18" bcor="0cm"
        secnumdepth="0" secsplitdepth="0">

        <head>
                <title><xsl:value-of select="$title"/></title>
                <author><xsl:value-of select="$author"/></author>
        </head>

        <make-toc depth="0" lof="no" lot="no" lol="no"/>

        <section>
            <title>Vocabulary</title>
            <table print-width="100%" screen-width="600px" align="left">
                <colgroup>
                    <col width="50%"/>
                    <col width="50%"/>
                </colgroup>
                <xsl:for-each select="/vocabulary/entry">
                    <tr>
                        <td><xsl:value-of select="source"/></td>
                        <td><xsl:value-of select="target"/></td>
                    </tr>
                </xsl:for-each>
            </table>
        </section>

</article> 
    </xsl:template>

</xsl:stylesheet>
