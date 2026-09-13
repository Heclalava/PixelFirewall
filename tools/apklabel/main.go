package main

import (
    "archive/zip"
    "bytes"
    "fmt"
    "io"
    "os"

    "github.com/chenhuifeng/androidbinary"
)

type Manifest struct {
    App Application `xml:"application"`
}

type Application struct {
    Label androidbinary.String `xml:"http://schemas.android.com/apk/res/android label,attr"`
}

func main() {
    if len(os.Args) != 2 {
        os.Exit(2)
    }

    f, err := os.Open(os.Args[1])
    if err != nil {
        os.Exit(1)
    }
    defer f.Close()

    st, err := f.Stat()
    if err != nil {
        os.Exit(1)
    }

    zr, err := zip.NewReader(f, st.Size())
    if err != nil {
        os.Exit(1)
    }

    readZip := func(name string) ([]byte, error) {
        for _, z := range zr.File {
            if z.Name != name {
                continue
            }
            r, err := z.Open()
            if err != nil {
                return nil, err
            }
            defer r.Close()
            return io.ReadAll(r)
        }
        return nil, fmt.Errorf("missing %s", name)
    }

    resData, err := readZip("resources.arsc")
    if err != nil {
        os.Exit(1)
    }

    table, err := androidbinary.NewTableFile(bytes.NewReader(resData))
    if err != nil {
        os.Exit(1)
    }

    xmlData, err := readZip("AndroidManifest.xml")
    if err != nil {
        os.Exit(1)
    }

    xmlFile, err := androidbinary.NewXMLFile(bytes.NewReader(xmlData))
    if err != nil {
        os.Exit(1)
    }

    var manifest Manifest
    if err := xmlFile.Decode(&manifest, table, nil); err != nil {
        os.Exit(1)
    }

    label, err := manifest.App.Label.WithResTableConfig(&androidbinary.ResTableConfig{}).String()
    if err != nil || label == "" || androidbinary.IsResID(label) {
        os.Exit(1)
    }

    fmt.Println(label)
}
